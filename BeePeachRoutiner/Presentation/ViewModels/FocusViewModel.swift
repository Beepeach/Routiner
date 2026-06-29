import Foundation
import RxSwift
import RxCocoa

// MARK: - FocusViewModel

/// Visual Dial 화면의 ViewModel. Input/Output 패턴.
///
/// 인터랙션 흐름:
/// 1. **idle**: 사용자가 다이얼 knob을 돌려 ratio (0~1) 를 정한다.
///    화면에는 `selectedRatio * maxDuration` 시간이 표시된다.
/// 2. **start**: 그 시점의 duration으로 `FocusSessionUseCase.start` 호출.
///    성공 시 isRunning=true, elapsed=0.
/// 3. **running**: 1초 간격 timer로 elapsed 증가. 링은 카운트다운(1→0).
///    시간 라벨은 `duration - elapsed` 로 줄어든다. 다이얼은 잠금.
/// 4. **cancel**: `FocusSessionUseCase.cancel` 호출. 성공 시 idle 로 복귀하되
///    `selectedRatio` 는 유지(사용자 의도 보존).
final class FocusViewModel {

    // MARK: - Input / Output

    struct Input {
        /// 사용자가 다이얼 knob을 회전시킬 때마다 발사되는 ratio (0~1).
        let dialRatioChanged: Observable<CGFloat>
        let startTapped: Observable<Void>
        let pauseTapped: Observable<Void>
        let resumeTapped: Observable<Void>
        let cancelTapped: Observable<Void>
    }

    struct Output {
        /// 링이 표시할 ratio (0~1). idle 에서는 사용자 설정값, 진행 중에는 (남은 시간 / maxDuration).
        let ringRatio: Driver<CGFloat>
        /// 시간 라벨. idle 에서는 설정한 duration, 진행 중에는 남은 시간.
        let timeText: Driver<String>
        /// 세션이 active 진행 중인지. timer 가 카운트다운하는 상태.
        let isRunning: Driver<Bool>
        /// 세션이 일시정지 상태인지. timer 는 멈춤, 시간/ringRatio 는 그대로.
        let isPaused: Driver<Bool>
        /// 다이얼 인터랙션 활성화 여부. running/paused 모두 false 로 잠근다.
        let isDialEnabled: Driver<Bool>
        /// UseCase 실패 시 흘러나오는 에러.
        let error: Driver<Error>
    }

    // MARK: - Dependencies

    private let useCase: FocusSessionUseCase
    /// 다이얼 한 바퀴(ratio=1)에 해당하는 최대 시간(초). 기본 60분.
    private let maxDuration: TimeInterval
    private let disposeBag = DisposeBag()

    // MARK: - Initialization

    init(useCase: FocusSessionUseCase, maxDuration: TimeInterval = 60 * 60) {
        self.useCase = useCase
        self.maxDuration = maxDuration
    }

    // MARK: - View Configuration

    /// 다이얼이 사용해야 할 ratio 스냅 step. 1분(=60초) 단위로 환산.
    /// 예: maxDuration 60분 → 1/60. ViewController가 ringView 에 전달한다.
    var ringSnapStep: CGFloat {
        guard maxDuration > 0 else { return 0 }
        return CGFloat(60.0 / maxDuration)
    }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        let selectedRatioRelay = BehaviorRelay<CGFloat>(value: 0)
        let isRunningRelay = BehaviorRelay<Bool>(value: false)
        let isPausedRelay = BehaviorRelay<Bool>(value: false)
        let activeSessionRelay = BehaviorRelay<FocusSession?>(value: nil)
        let elapsedRelay = BehaviorRelay<TimeInterval>(value: 0)
        let errorSubject = PublishSubject<Error>()

        bindDial(
            dialRatioChanged: input.dialRatioChanged,
            isRunningRelay: isRunningRelay,
            isPausedRelay: isPausedRelay,
            selectedRatioRelay: selectedRatioRelay
        )

        bindStart(
            startTapped: input.startTapped,
            isRunningRelay: isRunningRelay,
            isPausedRelay: isPausedRelay,
            selectedRatioRelay: selectedRatioRelay,
            activeSessionRelay: activeSessionRelay,
            elapsedRelay: elapsedRelay,
            errorSubject: errorSubject
        )

        bindPause(
            pauseTapped: input.pauseTapped,
            isRunningRelay: isRunningRelay,
            isPausedRelay: isPausedRelay,
            activeSessionRelay: activeSessionRelay,
            errorSubject: errorSubject
        )

        bindResume(
            resumeTapped: input.resumeTapped,
            isRunningRelay: isRunningRelay,
            isPausedRelay: isPausedRelay,
            activeSessionRelay: activeSessionRelay,
            errorSubject: errorSubject
        )

        bindCancel(
            cancelTapped: input.cancelTapped,
            isRunningRelay: isRunningRelay,
            isPausedRelay: isPausedRelay,
            activeSessionRelay: activeSessionRelay,
            elapsedRelay: elapsedRelay,
            errorSubject: errorSubject
        )

        bindTimer(
            isRunningRelay: isRunningRelay,
            elapsedRelay: elapsedRelay
        )

        let ringRatio = Observable
            .combineLatest(selectedRatioRelay, elapsedRelay, activeSessionRelay)
            .map { [maxDuration] ratio, elapsed, session -> CGFloat in
                // 진행 중에는 (남은 시간 / 다이얼 최대 시간) 으로 계산해야
                // 시작 직후 사용자가 설정한 위치(selectedRatio)에서 그대로 출발한다.
                // 분모를 session.duration 으로 두면 항상 1.0 에서 출발하는 점프가 생긴다.
                guard let session, maxDuration > 0 else { return ratio }
                let remaining = max(session.duration - elapsed, 0)
                return CGFloat(remaining / maxDuration)
            }
            .asDriver(onErrorJustReturn: 0)

        let timeText = Observable
            .combineLatest(selectedRatioRelay, elapsedRelay, activeSessionRelay)
            .map { [maxDuration] ratio, elapsed, session -> String in
                if let session {
                    return Self.format(seconds: max(session.duration - elapsed, 0))
                }
                return Self.format(seconds: maxDuration * TimeInterval(ratio))
            }
            .asDriver(onErrorJustReturn: "00:00")

        let isDialEnabled = Observable
            .combineLatest(isRunningRelay, isPausedRelay)
            .map { running, paused in !running && !paused }
            .asDriver(onErrorJustReturn: true)

        return Output(
            ringRatio: ringRatio,
            timeText: timeText,
            isRunning: isRunningRelay.asDriver(),
            isPaused: isPausedRelay.asDriver(),
            isDialEnabled: isDialEnabled,
            error: errorSubject.asDriver(onErrorDriveWith: .empty())
        )
    }

    // MARK: - Bindings

    private func bindDial(
        dialRatioChanged: Observable<CGFloat>,
        isRunningRelay: BehaviorRelay<Bool>,
        isPausedRelay: BehaviorRelay<Bool>,
        selectedRatioRelay: BehaviorRelay<CGFloat>
    ) {
        dialRatioChanged
            .withLatestFrom(Observable.combineLatest(isRunningRelay, isPausedRelay)) {
                ratio, running_paused in (ratio, running_paused.0, running_paused.1)
            }
            .filter { _, running, paused in !running && !paused } // idle 일 때만 다이얼 입력 수용
            .map { ratio, _, _ in ratio }
            .bind(to: selectedRatioRelay)
            .disposed(by: disposeBag)
    }

    private func bindStart(
        startTapped: Observable<Void>,
        isRunningRelay: BehaviorRelay<Bool>,
        isPausedRelay: BehaviorRelay<Bool>,
        selectedRatioRelay: BehaviorRelay<CGFloat>,
        activeSessionRelay: BehaviorRelay<FocusSession?>,
        elapsedRelay: BehaviorRelay<TimeInterval>,
        errorSubject: PublishSubject<Error>
    ) {
        let useCase = self.useCase
        let maxDuration = self.maxDuration

        startTapped
            .withLatestFrom(Observable.combineLatest(isRunningRelay, isPausedRelay, selectedRatioRelay))
            .filter { running, paused, ratio in !running && !paused && ratio > 0 }
            .map { _, _, ratio in maxDuration * TimeInterval(ratio) }
            .flatMapLatest { duration -> Observable<Event<FocusSession>> in
                Self.singleFromAsync { try await useCase.start(duration: duration, goal: nil) }
                    .materialize()
            }
            .subscribe(onNext: { event in
                switch event {
                case .next(let session):
                    activeSessionRelay.accept(session)
                    elapsedRelay.accept(0)
                    isRunningRelay.accept(true)
                case .error(let err):
                    errorSubject.onNext(err)
                case .completed:
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    private func bindPause(
        pauseTapped: Observable<Void>,
        isRunningRelay: BehaviorRelay<Bool>,
        isPausedRelay: BehaviorRelay<Bool>,
        activeSessionRelay: BehaviorRelay<FocusSession?>,
        errorSubject: PublishSubject<Error>
    ) {
        let useCase = self.useCase

        pauseTapped
            .withLatestFrom(Observable.combineLatest(isRunningRelay, activeSessionRelay))
            .filter { running, session in running && session != nil }
            .compactMap { _, session in session }
            .flatMapLatest { session -> Observable<Event<FocusSession>> in
                Self.singleFromAsync { try await useCase.pause(sessionId: session.id) }
                    .materialize()
            }
            .subscribe(onNext: { event in
                switch event {
                case .next(let updated):
                    activeSessionRelay.accept(updated)
                    isRunningRelay.accept(false)
                    isPausedRelay.accept(true)
                case .error(let err):
                    errorSubject.onNext(err)
                case .completed:
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    private func bindResume(
        resumeTapped: Observable<Void>,
        isRunningRelay: BehaviorRelay<Bool>,
        isPausedRelay: BehaviorRelay<Bool>,
        activeSessionRelay: BehaviorRelay<FocusSession?>,
        errorSubject: PublishSubject<Error>
    ) {
        let useCase = self.useCase

        resumeTapped
            .withLatestFrom(Observable.combineLatest(isPausedRelay, activeSessionRelay))
            .filter { paused, session in paused && session != nil }
            .compactMap { _, session in session }
            .flatMapLatest { session -> Observable<Event<FocusSession>> in
                Self.singleFromAsync { try await useCase.resume(sessionId: session.id) }
                    .materialize()
            }
            .subscribe(onNext: { event in
                switch event {
                case .next(let updated):
                    activeSessionRelay.accept(updated)
                    isPausedRelay.accept(false)
                    isRunningRelay.accept(true)
                case .error(let err):
                    errorSubject.onNext(err)
                case .completed:
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    private func bindCancel(
        cancelTapped: Observable<Void>,
        isRunningRelay: BehaviorRelay<Bool>,
        isPausedRelay: BehaviorRelay<Bool>,
        activeSessionRelay: BehaviorRelay<FocusSession?>,
        elapsedRelay: BehaviorRelay<TimeInterval>,
        errorSubject: PublishSubject<Error>
    ) {
        let useCase = self.useCase

        cancelTapped
            .withLatestFrom(activeSessionRelay)
            .compactMap { $0 }
            .flatMapLatest { session -> Observable<Event<FocusSession>> in
                Self.singleFromAsync { try await useCase.cancel(sessionId: session.id) }
                    .materialize()
            }
            .subscribe(onNext: { event in
                switch event {
                case .next:
                    isRunningRelay.accept(false)
                    isPausedRelay.accept(false)
                    activeSessionRelay.accept(nil)
                    elapsedRelay.accept(0)
                case .error(let err):
                    errorSubject.onNext(err)
                case .completed:
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    private func bindTimer(
        isRunningRelay: BehaviorRelay<Bool>,
        elapsedRelay: BehaviorRelay<TimeInterval>
    ) {
        isRunningRelay
            .distinctUntilChanged()
            .flatMapLatest { running -> Observable<Int> in
                guard running else { return .empty() }
                return Observable<Int>.interval(.seconds(1), scheduler: MainScheduler.instance)
            }
            .withLatestFrom(elapsedRelay) { _, elapsed in elapsed + 1 }
            .bind(to: elapsedRelay)
            .disposed(by: disposeBag)
    }

    // MARK: - Helpers

    /// async 호출을 Rx Single → Observable 로 감싼다. dispose 시 Task가 취소되도록 묶는다.
    private static func singleFromAsync<T>(
        _ work: @escaping @Sendable () async throws -> T
    ) -> Observable<T> {
        Single.create { single in
            let task = Task {
                do {
                    let value = try await work()
                    single(.success(value))
                } catch {
                    single(.failure(error))
                }
            }
            return Disposables.create { task.cancel() }
        }
        .asObservable()
    }

    /// 시간을 "MM:SS" 로 포맷한다. 소수점은 올림 처리.
    /// `seconds - epsilon` 으로 1ms 미만의 floating point 오차를 흡수한 뒤 ceiling.
    /// 보정이 없으면 `0.4833 * 3600 = 1739.9999...` 같은 1.0 직전 값이 1.0 너머로 떠
    /// `rounded(.up)` 가 분 step 직후 잠깐 "+1초" 를 표시하는 깜빡임이 발생한다.
    private static func format(seconds: TimeInterval) -> String {
        let epsilon: TimeInterval = 0.001
        let total = max(0, Int((seconds - epsilon).rounded(.up)))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
