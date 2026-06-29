import UIKit
import RxSwift
import RxCocoa
import SnapKit

// MARK: - FocusViewController

/// Visual Dial 타이머 화면.
///
/// - 원형 다이얼: `CircularProgressRingView`. knob 을 PanGesture 로 돌려 시간 설정.
/// - 시간 라벨: idle 에서는 설정한 시간, 진행 중에는 남은 시간 ("MM:SS").
/// - 컨트롤: 단일 `primaryButton` 이 상태에 따라 텍스트/액션이 바뀐다.
///   - idle:   "Start"  → 세션 시작
///   - running:"Pause"  → 일시정지
///   - paused: "Resume" → 재개
///   `cancelButton` 은 running/paused 상태에서만 노출되어 세션을 취소한다.
final class FocusViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: FocusViewModel
    private let disposeBag = DisposeBag()

    /// 사용자가 다이얼 knob 을 회전시킬 때 ratio 를 ViewModel 로 전달하는 통로.
    private let dialRatioSubject = PublishSubject<CGFloat>()

    /// primaryButton tap 을 현재 상태(idle/running/paused)에 따라 분기하기 위한 통로들.
    private let startSubject = PublishSubject<Void>()
    private let pauseSubject = PublishSubject<Void>()
    private let resumeSubject = PublishSubject<Void>()

    // MARK: - State Snapshot

    /// primaryButton tap 분기에 쓰는 현재 상태 스냅샷.
    /// Driver(`isRunning`, `isPaused`) 두 값을 별도 관리하는 대신 합쳐서 enum 으로 보관한다.
    private enum SessionState { case idle, running, paused }
    private var currentState: SessionState = .idle

    // MARK: - UI

    private let ringView = CircularProgressRingView()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 56, weight: .bold)
        label.textAlignment = .center
        label.text = "00:00"
        return label
    }()

    private let primaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        return button
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        button.tintColor = .systemRed
        button.isHidden = true
        return button
    }()

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

        view.addSubview(ringView)
        ringView.addSubview(timeLabel)
        view.addSubview(cancelButton)
        view.addSubview(primaryButton)

        ringView.snp.makeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.centerY.equalTo(view.safeAreaLayoutGuide).offset(-40)
            make.width.height.equalTo(300)
        }
        timeLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        // 기본 위치: primaryButton 가운데, cancelButton 그 왼쪽.
        primaryButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(ringView.snp.bottom).offset(40)
            make.height.equalTo(56)
            make.width.equalTo(160)
        }
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(primaryButton.snp.leading).offset(-16)
            make.centerY.equalTo(primaryButton)
            make.height.equalTo(primaryButton)
            make.width.equalTo(120)
        }
    }

    private func setupRingViewCallbacks() {
        ringView.snapStep = viewModel.ringSnapStep
        ringView.onRatioChanged = { [weak self] ratio in
            self?.dialRatioSubject.onNext(ratio)
        }
    }

    // MARK: - Binding

    private func bindViewModel() {
        // primary 버튼 한 개를 현재 상태에 따라 start/pause/resume 로 분기.
        primaryButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                switch self.currentState {
                case .idle:    self.startSubject.onNext(())
                case .running: self.pauseSubject.onNext(())
                case .paused:  self.resumeSubject.onNext(())
                }
            })
            .disposed(by: disposeBag)

        let input = FocusViewModel.Input(
            dialRatioChanged: dialRatioSubject.asObservable(),
            startTapped: startSubject.asObservable(),
            pauseTapped: pauseSubject.asObservable(),
            resumeTapped: resumeSubject.asObservable(),
            cancelTapped: cancelButton.rx.tap.asObservable()
        )
        let output = viewModel.transform(input: input)

        // running 중에는 1초 간격 timer tick 사이를 1초 보간으로 채워 카운트다운을 매끄럽게.
        // idle/cancel 시에는 즉시 반영해 다이얼 입력 반응성을 유지.
        Driver.combineLatest(output.ringRatio, output.isRunning)
            .drive(onNext: { [weak self] ratio, running in
                self?.ringView.setRatio(ratio, animationDuration: running ? 1.0 : 0)
            })
            .disposed(by: disposeBag)

        output.timeText
            .drive(timeLabel.rx.text)
            .disposed(by: disposeBag)

        // running/paused 조합으로 currentState 갱신 + 버튼 텍스트/노출 토글
        Driver.combineLatest(output.isRunning, output.isPaused)
            .drive(onNext: { [weak self] running, paused in
                guard let self else { return }
                let state: SessionState = running ? .running : (paused ? .paused : .idle)
                self.currentState = state
                self.applyState(state)
            })
            .disposed(by: disposeBag)

        output.isDialEnabled
            .drive(onNext: { [weak self] enabled in
                self?.ringView.isDialEnabled = enabled
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
        case .idle:
            primaryButton.setTitle("Start", for: .normal)
            cancelButton.isHidden = true
        case .running:
            primaryButton.setTitle("Pause", for: .normal)
            cancelButton.isHidden = false
        case .paused:
            primaryButton.setTitle("Resume", for: .normal)
            cancelButton.isHidden = false
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
