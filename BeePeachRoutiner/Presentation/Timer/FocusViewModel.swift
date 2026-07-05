import Foundation
import RxSwift
import RxCocoa

// MARK: - FocusViewModel

/// Focus 화면의 ViewModel. Input/Output 패턴.
///
/// 인터랙션 흐름:
/// 1. **idle**: 사용자가 다이얼 knob(ratio) 또는 휠 피커(분/초)로 duration 을 정한다.
///    두 입력 모두 `selectedDuration` 단일 상태로 합류한다.
/// 2. **start**: 그 시점의 duration 으로 `FocusSessionUseCase.start` 호출.
///    성공 시 isRunning=true, elapsed=0.
/// 3. **running**: 1초 간격 timer로 elapsed 증가. 링/휠/라벨 모두 남은 시간을
///    라이브로 비춘다 — 모드(dial/digital)는 표시 방식일 뿐이라 전환은 항상 허용,
///    다이얼·휠 *입력*만 잠근다.
/// 4. **cancel**: `FocusSessionUseCase.end(workNote: nil)` 호출 — 도메인이 누적
///    시간 기준으로 completed/cancelled 를 판정한다. 성공 시 idle 로 복귀하되
///    `selectedDuration` 은 유지(사용자 의도 보존). 작업기록(workNote) 입력
///    모달은 후속 태스크에서 연결한다.
final class FocusViewModel {

    // MARK: - Input / Output

    struct Input {
        /// 사용자가 다이얼 knob을 회전시킬 때마다 발사되는 ratio (0~1).
        let dialRatioChanged: Observable<CGFloat>
        /// 사용자가 휠 피커에서 고른 duration(초). Digital Mode 입력.
        let wheelDurationChanged: Observable<TimeInterval>
        /// 사용자가 세그먼트로 고른 표시 모드.
        let modeChanged: Observable<FocusMode>
        let startTapped: Observable<Void>
        let pauseTapped: Observable<Void>
        let resumeTapped: Observable<Void>
        let cancelTapped: Observable<Void>
    }

    struct Output {
        /// 링이 표시할 ratio (0~1). idle 에서는 사용자 설정값, 진행 중에는 (남은 시간 / maxDuration).
        let ringRatio: Driver<CGFloat>
        /// 휠이 표시할 시간(초). idle 에서는 사용자 설정값, 진행 중에는 남은 시간.
        /// ringRatio 와 대칭 — 모드는 표시 방식일 뿐이라 두 뷰가 같은 상태를 라이브로 비춘다.
        let wheelDuration: Driver<TimeInterval>
        /// 시간 라벨. idle 에서는 설정한 duration, 진행 중에는 남은 시간.
        let timeText: Driver<String>
        /// 현재 표시 모드. 세그먼트 인덱스/뷰 토글 동기화용.
        let mode: Driver<FocusMode>
        /// 세션이 active 진행 중인지. timer 가 카운트다운하는 상태.
        let isRunning: Driver<Bool>
        /// 세션이 일시정지 상태인지. timer 는 멈춤, 시간/ringRatio 는 그대로.
        let isPaused: Driver<Bool>
        /// 다이얼/휠 인터랙션 활성화 여부. running/paused 모두 false 로 잠근다.
        /// 입력만 잠글 뿐 모드 전환은 항상 허용된다.
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

    // swiftlang/swift#87316 워크어라운드: MainActor 기본 격리가 합성하는 isolated deinit이
    // 동기 컨텍스트 해제 시(XCTest 등) 런타임 크래시를 일으켜 nonisolated로 고정한다.
    nonisolated deinit {}

    // MARK: - View Configuration

    /// 다이얼이 사용해야 할 ratio 스냅 step. 1분(=60초) 단위로 환산.
    /// 예: maxDuration 60분 → 1/60. ViewController가 ringView 에 전달한다.
    var ringSnapStep: CGFloat {
        guard maxDuration > 0 else { return 0 }
        return CGFloat(60.0 / maxDuration)
    }

    /// 휠 피커가 컴포넌트 범위를 파생할 최대 시간. ringSnapStep 과 동일한 주입 패턴.
    var wheelMaxDuration: TimeInterval { maxDuration }

    // MARK: - Transform

    func transform(input: Input) -> Output {
        // 사용자가 고른 목표 시간(초). 다이얼 ratio는 VM 경계에서 duration 으로 환산해
        // 단일 진실 원천으로 관리한다 (휠 등 다른 입력 수단이 같은 상태를 공유하기 위함).
        let selectedDurationRelay = BehaviorRelay<TimeInterval>(value: 0)
        let modeRelay = BehaviorRelay<FocusMode>(value: .dial)
        let isRunningRelay = BehaviorRelay<Bool>(value: false)
        let isPausedRelay = BehaviorRelay<Bool>(value: false)
        let activeSessionRelay = BehaviorRelay<FocusSession?>(value: nil)
        let elapsedRelay = BehaviorRelay<TimeInterval>(value: 0)
        let errorSubject = PublishSubject<Error>()

        bindDial(
            dialRatioChanged: input.dialRatioChanged,
            isRunningRelay: isRunningRelay,
            isPausedRelay: isPausedRelay,
            selectedDurationRelay: selectedDurationRelay
        )

        bindWheel(
            wheelDurationChanged: input.wheelDurationChanged,
            isRunningRelay: isRunningRelay,
            isPausedRelay: isPausedRelay,
            selectedDurationRelay: selectedDurationRelay
        )

        bindMode(
            modeChanged: input.modeChanged,
            modeRelay: modeRelay
        )

        bindStart(
            startTapped: input.startTapped,
            isRunningRelay: isRunningRelay,
            isPausedRelay: isPausedRelay,
            selectedDurationRelay: selectedDurationRelay,
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
            .combineLatest(selectedDurationRelay, elapsedRelay, activeSessionRelay)
            .map { [maxDuration] duration, elapsed, session -> CGFloat in
                guard maxDuration > 0 else { return 0 }
                // 진행 중에는 (남은 시간 / 다이얼 최대 시간) 으로 계산해야
                // 시작 직후 사용자가 설정한 위치에서 그대로 출발한다.
                // 분모를 session.duration 으로 두면 항상 1.0 에서 출발하는 점프가 생긴다.
                guard let session else { return CGFloat(duration / maxDuration) }
                let remaining = max(session.duration - elapsed, 0)
                return CGFloat(remaining / maxDuration)
            }
            .asDriver(onErrorJustReturn: 0)

        // 링과 동일 시멘틱의 휠 표시값: 진행 중에는 남은 시간, idle 에는 선택값.
        // 모드는 표시 방식일 뿐이므로 두 뷰가 같은 세션을 라이브로 비춘다.
        let wheelDuration = Observable
            .combineLatest(selectedDurationRelay, elapsedRelay, activeSessionRelay)
            .map { duration, elapsed, session -> TimeInterval in
                guard let session else { return duration }
                return max(session.duration - elapsed, 0)
            }
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: 0)

        let timeText = Observable
            .combineLatest(selectedDurationRelay, elapsedRelay, activeSessionRelay)
            .map { duration, elapsed, session -> String in
                if let session {
                    return Self.format(seconds: max(session.duration - elapsed, 0))
                }
                return Self.format(seconds: duration)
            }
            .asDriver(onErrorJustReturn: "00:00")

        let isDialEnabled = Observable
            .combineLatest(isRunningRelay, isPausedRelay)
            .map { running, paused in !running && !paused }
            .asDriver(onErrorJustReturn: true)

        return Output(
            ringRatio: ringRatio,
            wheelDuration: wheelDuration,
            timeText: timeText,
            mode: modeRelay.asDriver().distinctUntilChanged(),
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
        selectedDurationRelay: BehaviorRelay<TimeInterval>
    ) {
        let maxDuration = self.maxDuration

        dialRatioChanged
            .withLatestFrom(Observable.combineLatest(isRunningRelay, isPausedRelay)) {
                ratio, running_paused in (ratio, running_paused.0, running_paused.1)
            }
            .filter { _, running, paused in !running && !paused } // idle 일 때만 다이얼 입력 수용
            .map { ratio, _, _ in maxDuration * TimeInterval(ratio) }
            .bind(to: selectedDurationRelay)
            .disposed(by: disposeBag)
    }

    private func bindWheel(
        wheelDurationChanged: Observable<TimeInterval>,
        isRunningRelay: BehaviorRelay<Bool>,
        isPausedRelay: BehaviorRelay<Bool>,
        selectedDurationRelay: BehaviorRelay<TimeInterval>
    ) {
        let maxDuration = self.maxDuration

        wheelDurationChanged
            .withLatestFrom(Observable.combineLatest(isRunningRelay, isPausedRelay)) {
                duration, running_paused in (duration, running_paused.0, running_paused.1)
            }
            .filter { _, running, paused in !running && !paused } // idle 일 때만 휠 입력 수용
            // 뷰가 이미 clamp 하지만 VM 불변식을 뷰 정합성에 의존시키지 않는 이중 방어.
            .map { duration, _, _ in max(0, min(duration, maxDuration)) }
            .bind(to: selectedDurationRelay)
            .disposed(by: disposeBag)
    }

    private func bindMode(
        modeChanged: Observable<FocusMode>,
        modeRelay: BehaviorRelay<FocusMode>
    ) {
        // 모드는 순수 뷰 토글이라 세션 상태와 무관하게 항상 수용한다.
        modeChanged
            .bind(to: modeRelay)
            .disposed(by: disposeBag)
    }

    private func bindStart(
        startTapped: Observable<Void>,
        isRunningRelay: BehaviorRelay<Bool>,
        isPausedRelay: BehaviorRelay<Bool>,
        selectedDurationRelay: BehaviorRelay<TimeInterval>,
        activeSessionRelay: BehaviorRelay<FocusSession?>,
        elapsedRelay: BehaviorRelay<TimeInterval>,
        errorSubject: PublishSubject<Error>
    ) {
        let useCase = self.useCase

        startTapped
            .withLatestFrom(
                Observable.combineLatest(isRunningRelay, isPausedRelay, selectedDurationRelay)
            )
            .filter { running, paused, duration in !running && !paused && duration > 0 }
            .map { _, _, duration in duration }
            .flatMapLatest { duration -> Observable<Event<FocusSession>> in
                Self.singleFromAsync { try await useCase.start(duration: duration) }
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
                Self.singleFromAsync { try await useCase.end(sessionId: session.id, workNote: nil) }
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
