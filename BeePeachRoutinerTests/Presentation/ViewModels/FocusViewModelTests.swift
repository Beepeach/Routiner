import XCTest
import RxSwift
import RxCocoa
@testable import BeePeachRoutiner

final class FocusViewModelTests: XCTestCase {

    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        disposeBag = nil
        super.tearDown()
    }

    // MARK: - dial

    func test_dialRatioChanged_shouldUpdateTimeText_whenIdle() {
        // Given: maxDuration 60분
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)

        var captured: [String] = []
        runtime.output.timeText
            .drive(onNext: { captured.append($0) })
            .disposed(by: disposeBag)

        // When: ratio 0.5 (30분)
        runtime.dialSubject.onNext(0.5)

        // Then
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(captured.last, "30:00")
    }

    func test_dialRatioChanged_shouldBeIgnored_whenRunning() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        // 사용자 ratio 0.5 → start
        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        // When: 진행 중에 dial을 0.9 로 돌림
        runtime.dialSubject.onNext(0.9)

        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        // Then: useCase 호출은 첫 ratio(0.5) 기반 = 1800초 그대로
        XCTAssertEqual(useCase.lastStartedDuration, 1800)
    }

    // MARK: - start

    func test_start_shouldUseRatioBasedDuration_whenIdle() {
        // Given: maxDuration 60분, ratio 0.25 (15분)
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        // When
        runtime.dialSubject.onNext(0.25)
        runtime.startSubject.onNext(())

        // Then
        wait(for: [runningExp], timeout: 1.0)
        XCTAssertEqual(useCase.startCallCount, 1)
        XCTAssertEqual(useCase.lastStartedDuration, 900) // 15분
    }

    func test_start_shouldBeIgnored_whenRatioIsZero() {
        // Given: ratio 0 (시간 미설정)
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase)
        let runtime = bind(sut)

        // When
        runtime.startSubject.onNext(())

        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        // Then
        XCTAssertEqual(useCase.startCallCount, 0)
    }

    func test_start_shouldEmitError_whenUseCaseThrows() {
        // Given
        struct StubError: Error {}
        let useCase = FocusSessionUseCaseStub()
        useCase.startError = StubError()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)

        let exp = expectation(description: "error emitted")
        runtime.output.error
            .drive(onNext: { _ in exp.fulfill() })
            .disposed(by: disposeBag)

        // When
        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())

        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(useCase.startCallCount, 1)
    }

    func test_start_shouldBeIgnored_whenAlreadyRunning() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        // When: 첫 start 후 추가 start 발사
        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)
        runtime.startSubject.onNext(())

        // Then: 두 번째 start 무시되어 호출 카운트 1 유지
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(useCase.startCallCount, 1)
    }

    // MARK: - pause / resume

    func test_pause_shouldCallUseCase_andSetIsPaused_whenRunning() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        let pausedExp = expectation(description: "isPaused becomes true")
        runtime.output.isPaused
            .asObservable()
            .skip(1)
            .filter { $0 }
            .take(1)
            .subscribe(onNext: { _ in pausedExp.fulfill() })
            .disposed(by: disposeBag)

        // When
        runtime.pauseSubject.onNext(())

        // Then
        wait(for: [pausedExp], timeout: 1.0)
        XCTAssertEqual(useCase.pauseCallCount, 1)
    }

    func test_pause_shouldBeIgnored_whenNotRunning() {
        // Given: idle 상태
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)

        // When
        runtime.pauseSubject.onNext(())

        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        // Then
        XCTAssertEqual(useCase.pauseCallCount, 0)
    }

    func test_resume_shouldCallUseCase_andResumeRunning_whenPaused() {
        // Given: start → pause
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        let pausedExp = expectation(description: "paused")
        runtime.output.isPaused
            .asObservable()
            .skip(1)
            .filter { $0 }
            .take(1)
            .subscribe(onNext: { _ in pausedExp.fulfill() })
            .disposed(by: disposeBag)
        runtime.pauseSubject.onNext(())
        wait(for: [pausedExp], timeout: 1.0)

        let resumedExp = expectation(description: "resumed")
        runtime.output.isRunning
            .asObservable()
            .skip(1)
            .filter { $0 }
            .take(1)
            .subscribe(onNext: { _ in resumedExp.fulfill() })
            .disposed(by: disposeBag)

        // When
        runtime.resumeSubject.onNext(())

        // Then
        wait(for: [resumedExp], timeout: 1.0)
        XCTAssertEqual(useCase.resumeCallCount, 1)
    }

    // MARK: - cancel

    func test_cancel_shouldCallUseCase_andResetIsRunning_whenRunning() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        let cancelledExp = expectation(description: "isRunning becomes false after cancel")
        runtime.output.isRunning
            .asObservable()
            .skip(1)
            .filter { !$0 }
            .take(1)
            .subscribe(onNext: { _ in cancelledExp.fulfill() })
            .disposed(by: disposeBag)

        // When
        runtime.cancelSubject.onNext(())

        // Then
        wait(for: [cancelledExp], timeout: 1.0)
        XCTAssertEqual(useCase.endCallCount, 1)
        XCTAssertNotNil(useCase.lastEndedSessionId)
        XCTAssertNil(useCase.lastEndedWorkNote, "취소 버튼 종료는 workNote 없이 end 를 호출해야 합니다")
    }

    func test_cancel_shouldBeIgnored_whenNoActiveSession() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase)
        let runtime = bind(sut)

        // When
        runtime.cancelSubject.onNext(())

        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        // Then
        XCTAssertEqual(useCase.endCallCount, 0)
    }

    // MARK: - isDialEnabled

    func test_isDialEnabled_shouldReflectRunningState() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)

        var values: [Bool] = []
        runtime.output.isDialEnabled
            .drive(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        // When: idle → start → running
        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        // Then: idle 시 true, running 시 false 가 모두 흘러왔어야 한다
        XCTAssertTrue(values.contains(true))
        XCTAssertTrue(values.contains(false))
    }

    // MARK: - ringRatio

    func test_ringRatio_shouldEqualSelectedRatio_atStart() {
        // Given: maxDuration 60분, ratio 0.5 (30분)
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        var captured: [CGFloat] = []
        runtime.output.ringRatio
            .drive(onNext: { captured.append($0) })
            .disposed(by: disposeBag)

        // When
        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        // Then: 시작 직후 ringRatio 는 selectedRatio(0.5)와 같아야 한다.
        // (1.0 이면 100% 차오른 채 시작하는 버그)
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(Double(captured.last ?? -1), 0.5, accuracy: 0.0001)
    }

    func test_ringRatio_shouldDecreaseOverTime_whileRunning() {
        // Given: maxDuration 60초로 짧게 (1초 tick에 1/60 씩 감소)
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        runtime.dialSubject.onNext(0.5) // 30초 설정
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        let initialRatio = expectation(description: "initial ratio at start")
        var initial: CGFloat?
        runtime.output.ringRatio
            .drive(onNext: { value in
                if initial == nil {
                    initial = value
                    initialRatio.fulfill()
                }
            })
            .disposed(by: disposeBag)
        wait(for: [initialRatio], timeout: 1.0)

        // When: 1초가 지나면 다음 tick 에서 ringRatio 가 감소해야 한다.
        let after = expectation(description: "ringRatio decreased")
        runtime.output.ringRatio
            .asObservable()
            .skip(1)
            .take(1)
            .subscribe(onNext: { _ in after.fulfill() })
            .disposed(by: disposeBag)
        wait(for: [after], timeout: 2.0)

        // Then: 시작 직후 0.5, 1초 후엔 그보다 작아야 한다.
        XCTAssertEqual(Double(initial ?? -1), 0.5, accuracy: 0.0001)
    }

    // MARK: - wheel

    func test_wheelDurationChanged_shouldUpdateTimeText_whenIdle() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)

        var captured: [String] = []
        runtime.output.timeText
            .drive(onNext: { captured.append($0) })
            .disposed(by: disposeBag)

        // When: 휠에서 25분(1500초) 선택
        runtime.wheelSubject.onNext(1500)

        // Then
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(captured.last, "25:00")
    }

    func test_wheelDurationChanged_shouldClampToMaxDuration_whenExceedingMax() {
        // Given: maxDuration 60분
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        // When: 상한 초과값(60분 30초) 주입 후 start
        runtime.wheelSubject.onNext(3630)
        runtime.startSubject.onNext(())

        // Then: VM 이중 방어로 maxDuration 으로 clamp 된 값이 start 에 전달
        wait(for: [runningExp], timeout: 1.0)
        XCTAssertEqual(useCase.lastStartedDuration, 3600)
    }

    func test_wheelDurationChanged_shouldBeIgnored_whenRunning() {
        // Given: 다이얼 0.5 (1800초) 로 start
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        // When: 진행 중에 휠 입력
        runtime.wheelSubject.onNext(900)

        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        // Then: 시작 duration 그대로 (입력 잠금)
        XCTAssertEqual(useCase.lastStartedDuration, 1800)
    }

    // MARK: - wheelDuration output

    func test_wheelDuration_shouldEqualSelectedDuration_whenIdle() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)

        var captured: [TimeInterval] = []
        runtime.output.wheelDuration
            .drive(onNext: { captured.append($0) })
            .disposed(by: disposeBag)

        // When: 휠에서 25분 30초 선택
        runtime.wheelSubject.onNext(1530)

        // Then
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(captured.last, 1530)
    }

    func test_dialRatioChanged_shouldUpdateWheelDurationOutput_whenIdle() {
        // Given: 다이얼 입력이 휠 표시값으로 흘러야 두 모드가 같은 상태를 비춘다
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)

        var captured: [TimeInterval] = []
        runtime.output.wheelDuration
            .drive(onNext: { captured.append($0) })
            .disposed(by: disposeBag)

        // When: 다이얼 ratio 0.5 (30분)
        runtime.dialSubject.onNext(0.5)

        // Then
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(captured.last, 1800)
    }

    func test_wheelDuration_shouldCountDownRemaining_whenRunning() {
        // Given: 30초 세션 start (1초 tick 후 remaining 감소 관찰)
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        runtime.wheelSubject.onNext(30)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        var captured: [TimeInterval] = []
        let decreased = expectation(description: "wheelDuration decreased below 30")
        runtime.output.wheelDuration
            .drive(onNext: { value in
                captured.append(value)
                if value < 30 { decreased.fulfill() }
            })
            .disposed(by: disposeBag)

        // When: 1초 tick 대기
        // Then: 남은 시간(30 미만)으로 감소
        wait(for: [decreased], timeout: 2.0)
        XCTAssertEqual(captured.last, 29)
    }

    // MARK: - mode

    func test_modeChanged_shouldUpdateModeOutput_whenIdle() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)

        var captured: [FocusMode] = []
        runtime.output.mode
            .drive(onNext: { captured.append($0) })
            .disposed(by: disposeBag)

        // When
        runtime.modeSubject.onNext(.digital)

        // Then: 초기 .dial → .digital
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(captured, [.dial, .digital])
    }

    func test_modeChanged_shouldUpdateModeOutput_whenRunning() {
        // Given: 모드는 순수 뷰 토글 — 실행 중에도 전환이 허용돼야 한다
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        runtime.dialSubject.onNext(0.5)
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        var captured: [FocusMode] = []
        runtime.output.mode
            .drive(onNext: { captured.append($0) })
            .disposed(by: disposeBag)

        // When: 진행 중 digital 전환
        runtime.modeSubject.onNext(.digital)

        // Then
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(captured.last, .digital)
    }

    func test_start_shouldKeepCurrentMode_whenStartedFromDigital() {
        // Given: digital 모드에서 시작해도 자동 전환 없이 유지돼야 한다
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        var captured: [FocusMode] = []
        runtime.output.mode
            .drive(onNext: { captured.append($0) })
            .disposed(by: disposeBag)

        runtime.modeSubject.onNext(.digital)
        runtime.wheelSubject.onNext(1500)

        // When
        runtime.startSubject.onNext(())
        wait(for: [runningExp], timeout: 1.0)

        // Then
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(captured.last, .digital)
    }

    // MARK: - goal

    func test_start_shouldUseWheelDuration_whenSetViaWheel() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        // When: 휠에서 15분(900초) 선택 후 start
        runtime.wheelSubject.onNext(900)
        runtime.startSubject.onNext(())

        // Then
        wait(for: [runningExp], timeout: 1.0)
        XCTAssertEqual(useCase.lastStartedDuration, 900)
    }

    func test_start_shouldPassTrimmedGoal_whenGoalHasWhitespace() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        runtime.goalSubject.onNext("  Deep Work  ")
        runtime.dialSubject.onNext(0.5)

        // When
        runtime.startSubject.onNext(())

        // Then: 앞뒤 공백 제거된 goal 이 UseCase 로 전달
        wait(for: [runningExp], timeout: 1.0)
        XCTAssertEqual(useCase.lastStartedGoal?.title, "Deep Work")
    }

    func test_start_shouldPassNilGoal_whenGoalIsWhitespaceOnly() {
        // Given: 공백만 있는 입력은 goal 없음으로 취급
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)
        let runningExp = expectIsRunningBecomesTrue(runtime.output)

        runtime.goalSubject.onNext("   ")
        runtime.dialSubject.onNext(0.5)

        // When
        runtime.startSubject.onNext(())

        // Then
        wait(for: [runningExp], timeout: 1.0)
        XCTAssertEqual(useCase.startCallCount, 1)
        XCTAssertNil(useCase.lastStartedGoal)
    }

    // MARK: - timeText

    func test_timeText_shouldEmitZero_initially() {
        // Given
        let useCase = FocusSessionUseCaseStub()
        let sut = FocusViewModel(useCase: useCase, maxDuration: 60 * 60)
        let runtime = bind(sut)

        let exp = expectation(description: "first emission")
        var captured: String?
        runtime.output.timeText
            .drive(onNext: { value in
                if captured == nil {
                    captured = value
                    exp.fulfill()
                }
            })
            .disposed(by: disposeBag)

        // Then: 사용자가 다이얼을 돌리기 전 초기 시간은 0
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(captured, "00:00")
    }

    // MARK: - Helpers

    private struct Runtime {
        let dialSubject: PublishSubject<CGFloat>
        let wheelSubject: PublishSubject<TimeInterval>
        let modeSubject: PublishSubject<FocusMode>
        let goalSubject: PublishSubject<String?>
        let startSubject: PublishSubject<Void>
        let pauseSubject: PublishSubject<Void>
        let resumeSubject: PublishSubject<Void>
        let cancelSubject: PublishSubject<Void>
        let output: FocusViewModel.Output
    }

    private func bind(_ viewModel: FocusViewModel) -> Runtime {
        let dialSubject = PublishSubject<CGFloat>()
        let wheelSubject = PublishSubject<TimeInterval>()
        let modeSubject = PublishSubject<FocusMode>()
        let goalSubject = PublishSubject<String?>()
        let startSubject = PublishSubject<Void>()
        let pauseSubject = PublishSubject<Void>()
        let resumeSubject = PublishSubject<Void>()
        let cancelSubject = PublishSubject<Void>()
        let output = viewModel.transform(input: .init(
            dialRatioChanged: dialSubject.asObservable(),
            wheelDurationChanged: wheelSubject.asObservable(),
            modeChanged: modeSubject.asObservable(),
            goalChanged: goalSubject.asObservable(),
            startTapped: startSubject.asObservable(),
            pauseTapped: pauseSubject.asObservable(),
            resumeTapped: resumeSubject.asObservable(),
            cancelTapped: cancelSubject.asObservable()
        ))
        return Runtime(
            dialSubject: dialSubject,
            wheelSubject: wheelSubject,
            modeSubject: modeSubject,
            goalSubject: goalSubject,
            startSubject: startSubject,
            pauseSubject: pauseSubject,
            resumeSubject: resumeSubject,
            cancelSubject: cancelSubject,
            output: output
        )
    }

    /// `isRunning` 이 false → true 로 전이되는 첫 시점에 fulfill 되는 expectation.
    private func expectIsRunningBecomesTrue(_ output: FocusViewModel.Output) -> XCTestExpectation {
        let exp = expectation(description: "isRunning becomes true")
        output.isRunning
            .asObservable()
            .skip(1)
            .filter { $0 }
            .take(1)
            .subscribe(onNext: { _ in exp.fulfill() })
            .disposed(by: disposeBag)
        return exp
    }
}
