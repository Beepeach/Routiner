import UIKit
import RxSwift
import RxCocoa
import SnapKit

// MARK: - FocusViewController

/// Focus 타이머 화면.
///
/// - 모드 토글: navigation bar 의 세그먼트로 Visual Dial ↔ Digital 을 전환한다.
///   모드는 표시 방식일 뿐이라 실행 중에도 전환 가능 — 링과 휠 모두 같은 세션을
///   라이브로 비춘다 (링 감소 + 휠 tick down). 실행 중에는 *입력*만 잠근다.
/// - 원형 다이얼: `CircularProgressRingView`. knob 을 PanGesture 로 돌려 시간 설정.
/// - 휠 피커: `TimeWheelPickerView`. 분/초 정밀 입력 (Digital Mode).
/// - 시간 라벨: idle 에서는 설정한 시간, 진행 중에는 남은 시간 ("MM:SS").
/// - 컨트롤: `SessionControlCapsule` 하나로 통합. play/pause 버튼이 상태에 따라
///   start/pause/resume 로 분기하고, stop 버튼이 세션을 종료한다.
///   캡슐은 모드(Dial/Digital)와 무관하게 항상 노출된다 — 모드는 표시 방식일 뿐.
final class FocusViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: FocusViewModel
    private let disposeBag = DisposeBag()

    /// 사용자가 다이얼 knob 을 회전시킬 때 ratio 를 ViewModel 로 전달하는 통로.
    private let dialRatioSubject = PublishSubject<CGFloat>()

    /// 사용자가 휠 피커를 돌릴 때 duration 을 ViewModel 로 전달하는 통로.
    private let wheelDurationSubject = PublishSubject<TimeInterval>()

    /// play/pause tap 을 현재 상태(idle/running/paused)에 따라 분기하기 위한 통로들.
    private let startSubject = PublishSubject<Void>()
    private let pauseSubject = PublishSubject<Void>()
    private let resumeSubject = PublishSubject<Void>()

    /// 작업기록 모달이 확정한 종료 결과(저장: 텍스트, 닫기/스와이프: nil)를
    /// ViewModel 로 전달하는 통로.
    private let endConfirmedSubject = PublishSubject<String?>()

    // MARK: - State Snapshot

    /// play/pause tap 분기와 종료 플로우 가드에 쓰는 현재 상태 스냅샷.
    /// Driver(`isRunning`, `isPaused`) 두 값을 별도 관리하는 대신 합쳐서 보관한다.
    /// 캡슐과 case 가 1:1 이라 별도 enum 을 두지 않고 캡슐의 State 를 그대로 쓴다.
    private var currentState: SessionControlCapsule.State = .idle

    /// 만료/stop 시점에 모달을 띄울 수 없었던 경우(다른 탭, 알럿 위) 재시도 예약 플래그.
    /// sessionExpired 는 세션당 1회만 방출되므로 이벤트를 버리면 종료 플로우가 유실된다.
    private var isEndFlowPending = false

    // MARK: - UI

    private let modeSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [FocusMode.dial, FocusMode.digital].map(\.title))
        control.selectedSegmentIndex = FocusMode.dial.rawValue
        return control
    }()

    private let ringView = CircularProgressRingView()

    /// 생성에 viewModel 이 필요해 lazy. 초기 모드가 dial 이라 바인딩 전 플래시 방지로 숨긴다.
    private lazy var wheelPickerView: TimeWheelPickerView = {
        let picker = TimeWheelPickerView(maxDuration: viewModel.wheelMaxDuration)
        picker.isHidden = true
        return picker
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 56, weight: .bold)
        label.textAlignment = .center
        label.text = "00:00"
        return label
    }()

    private let controlCapsule = SessionControlCapsule()

    // MARK: - Initialization

    init(viewModel: FocusViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupRingViewCallbacks()
        bindViewModel()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationItem.titleView = modeSegmentedControl

        view.addSubview(ringView)
        ringView.addSubview(timeLabel)
        view.addSubview(wheelPickerView)
        view.addSubview(controlCapsule)

        ringView.snp.makeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.centerY.equalTo(view.safeAreaLayoutGuide).offset(-40)
            make.width.height.equalTo(300)
        }
        timeLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        // 휠은 다이얼과 같은 슬롯을 공유한다 (모드에 따라 isHidden 토글).
        // 높이는 UIPickerView intrinsic(216pt)에 위임.
        wheelPickerView.snp.makeConstraints { make in
            make.center.equalTo(ringView)
            make.width.equalTo(ringView)
        }
        // 캡슐은 하단 고정 — 다이얼/휠(중앙 슬롯)과 겹치지 않는다.
        controlCapsule.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
        }
    }

    private func setupRingViewCallbacks() {
        ringView.snapStep = viewModel.ringSnapStep
        ringView.onRatioChanged = { [weak self] ratio in
            self?.dialRatioSubject.onNext(ratio)
        }
        wheelPickerView.onDurationChanged = { [weak self] duration in
            self?.wheelDurationSubject.onNext(duration)
        }
    }

    // MARK: - Binding

    private func bindViewModel() {
        // play/pause 버튼 한 개를 현재 상태에 따라 start/pause/resume 로 분기.
        controlCapsule.onPlayPauseTapped = { [weak self] in
            guard let self else { return }
            switch currentState {
            case .idle:    startSubject.onNext(())
            case .running: pauseSubject.onNext(())
            case .paused:  resumeSubject.onNext(())
            }
        }
        controlCapsule.onStopTapped = { [weak self] in
            self?.beginEndFlow()
        }

        let input = FocusViewModel.Input(
            dialRatioChanged: dialRatioSubject.asObservable(),
            wheelDurationChanged: wheelDurationSubject.asObservable(),
            modeChanged: modeSegmentedControl.rx.selectedSegmentIndex
                .compactMap(FocusMode.init(rawValue:)),
            startTapped: startSubject.asObservable(),
            pauseTapped: pauseSubject.asObservable(),
            resumeTapped: resumeSubject.asObservable(),
            endConfirmed: endConfirmedSubject.asObservable()
        )
        let output = viewModel.transform(input: input)

        // running 중에는 1초 간격 timer tick 사이를 1초 보간으로 채워 카운트다운을 매끄럽게.
        // idle/cancel 시에는 즉시 반영해 다이얼 입력 반응성을 유지.
        Driver.combineLatest(output.ringRatio, output.isRunning)
            .drive(onNext: { [weak self] ratio, running in
                self?.ringView.setRatio(ratio, animationDuration: running ? 1.0 : 0)
            })
            .disposed(by: disposeBag)

        // 휠도 링과 동일하게 상시 동기화한다 — 숨겨진 모드에서도 최신값을 유지해
        // 전환 순간 catch-up 없이 값이 연속된다. running 중에는 row 스크롤 애니메이션으로 tick.
        // setDuration 은 콜백을 발화하지 않으므로 (programmatic selectRow 규약) 루프 없음.
        Driver.combineLatest(output.wheelDuration, output.isRunning)
            .drive(onNext: { [weak self] duration, running in
                self?.wheelPickerView.setDuration(duration, animated: running)
            })
            .disposed(by: disposeBag)

        // 모드 전환: 세그먼트 인덱스 동기화 + 다이얼/휠 표시 토글.
        // programmatic selectedSegmentIndex 설정은 .valueChanged 를 발사하지 않아 루프 없음.
        output.mode
            .drive(onNext: { [weak self] mode in
                guard let self else { return }
                self.modeSegmentedControl.selectedSegmentIndex = mode.rawValue
                self.ringView.isHidden = (mode == .digital)
                self.wheelPickerView.isHidden = (mode == .dial)
            })
            .disposed(by: disposeBag)

        output.timeText
            .drive(timeLabel.rx.text)
            .disposed(by: disposeBag)

        // running/paused 조합으로 currentState 갱신 + 캡슐 상태 동기화
        Driver.combineLatest(output.isRunning, output.isPaused)
            .drive(onNext: { [weak self] running, paused in
                guard let self else { return }
                let state: SessionControlCapsule.State =
                    running ? .running : (paused ? .paused : .idle)
                self.currentState = state
                self.controlCapsule.state = state
            })
            .disposed(by: disposeBag)

        // 실행 중 입력 잠금은 다이얼·휠 공통. 모드 전환(세그먼트)은 잠그지 않는다.
        output.isDialEnabled
            .drive(onNext: { [weak self] enabled in
                self?.ringView.isDialEnabled = enabled
                self?.wheelPickerView.isUserInteractionEnabled = enabled
            })
            .disposed(by: disposeBag)

        // 시간 소진도 stop tap 과 같은 종료 플로우를 태운다.
        output.sessionExpired
            .drive(onNext: { [weak self] in
                self?.beginEndFlow()
            })
            .disposed(by: disposeBag)

        output.error
            .drive(onNext: { [weak self] error in
                self?.presentError(error)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - End Flow

    /// stop tap 과 timer 만료가 공유하는 종료 플로우.
    ///
    /// - running 이면 먼저 pause 한다 — 도메인의 accumulatedElapsed 는 벽시계 기반이라
    ///   모달이 떠 있는 동안에도 계속 누적되어, 60초 문턱 판정(기록 여부)이
    ///   모달에 머문 시간에 좌우되는 것을 막기 위함이다.
    /// - 모달을 당장 띄울 수 없으면(다른 탭이라 window 밖, 알럿이 이미 present 중)
    ///   pending 으로 표시하고 조건이 풀리는 시점(viewDidAppear, 알럿 확인)에 재시도한다.
    ///   `sessionExpired` 는 세션당 1회만 방출되므로 여기서 버리면 종료 플로우가 유실된다.
    private func beginEndFlow() {
        guard currentState != .idle else { return }
        // 시간 동결은 present 가능 여부와 무관하게 즉시 — 재시도를 기다리는 동안
        // 집중 시간이 계속 누적되면 안 된다.
        if currentState == .running {
            pauseSubject.onNext(())
        }
        // presentedViewController 가드: 만료 방출과 stop tap 이 겹칠 때 이중 present 방지 겸
        // 알럿 위 present 실패 방지. window 가드: 다른 탭에서는 present 가 조용히 실패한다.
        guard presentedViewController == nil, viewIfLoaded?.window != nil else {
            isEndFlowPending = true
            return
        }
        isEndFlowPending = false
        let modal = WorkLogModalViewController()
        modal.onComplete = { [weak self] workNote in
            self?.endConfirmedSubject.onNext(workNote)
        }
        present(modal, animated: true)
    }

    /// 탭 복귀로 화면이 다시 보이면 유예된 종료 플로우를 이어간다.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        retryEndFlowIfPending()
    }

    private func retryEndFlowIfPending() {
        guard isEndFlowPending else { return }
        // 알럿 확인 직후에는 dismiss 애니메이션이 끝날 때까지 presentedViewController 가
        // 남아 있어 즉시 재시도하면 가드에 걸린다. 비워질 때까지 runloop 단위로 미룬다.
        guard presentedViewController == nil else {
            DispatchQueue.main.async { [weak self] in
                self?.retryEndFlowIfPending()
            }
            return
        }
        beginEndFlow()
    }

    // MARK: - Error

    private func presentError(_ error: Error) {
        let alert = UIAlertController(
            title: "오류",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        // 알럿이 떠 있는 동안 만료가 발생했으면 확인을 닫는 시점에 종료 플로우를 이어간다.
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.retryEndFlowIfPending()
        })
        present(alert, animated: true)
    }
}
