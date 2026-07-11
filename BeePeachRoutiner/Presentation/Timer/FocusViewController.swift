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

    /// 캡슐 stop tap 을 ViewModel 로 전달하는 통로.
    private let stopSubject = PublishSubject<Void>()

    // MARK: - State Snapshot

    /// primaryButton tap 분기에 쓰는 현재 상태 스냅샷.
    /// Driver(`isRunning`, `isPaused`) 두 값을 별도 관리하는 대신 합쳐서 enum 으로 보관한다.
    private enum SessionState { case idle, running, paused }
    private var currentState: SessionState = .idle

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
            self?.stopSubject.onNext(())
        }

        let input = FocusViewModel.Input(
            dialRatioChanged: dialRatioSubject.asObservable(),
            wheelDurationChanged: wheelDurationSubject.asObservable(),
            modeChanged: modeSegmentedControl.rx.selectedSegmentIndex
                .compactMap(FocusMode.init(rawValue:)),
            startTapped: startSubject.asObservable(),
            pauseTapped: pauseSubject.asObservable(),
            resumeTapped: resumeSubject.asObservable(),
            cancelTapped: stopSubject.asObservable()
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
                let state: SessionState = running ? .running : (paused ? .paused : .idle)
                self.currentState = state
                self.applyState(state)
            })
            .disposed(by: disposeBag)

        // 실행 중 입력 잠금은 다이얼·휠 공통. 모드 전환(세그먼트)은 잠그지 않는다.
        output.isDialEnabled
            .drive(onNext: { [weak self] enabled in
                self?.ringView.isDialEnabled = enabled
                self?.wheelPickerView.isUserInteractionEnabled = enabled
            })
            .disposed(by: disposeBag)

        output.error
            .drive(onNext: { [weak self] error in
                self?.presentError(error)
            })
            .disposed(by: disposeBag)
    }

    private func applyState(_ state: SessionState) {
        switch state {
        case .idle:    controlCapsule.state = .idle
        case .running: controlCapsule.state = .running
        case .paused:  controlCapsule.state = .paused
        }
    }

    // MARK: - Error

    private func presentError(_ error: Error) {
        let alert = UIAlertController(
            title: "오류",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
