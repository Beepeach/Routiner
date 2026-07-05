import XCTest
@testable import BeePeachRoutiner

final class FocusSessionUseCaseTests: XCTestCase {

    // MARK: - start

    func test_start_shouldReturnActiveSessionWithEmptyAccumulation_whenCalled() async throws {
        // Given
        let stub = FocusSessionRepositoryStub()
        let sut = DefaultFocusSessionUseCase(repository: stub)

        // When
        let result = try await sut.start(duration: 1500)

        // Then
        XCTAssertEqual(result.status, .active)
        XCTAssertNil(result.completedAt)
        XCTAssertEqual(result.duration, 1500)
        XCTAssertEqual(result.accumulatedElapsed, 0)
        XCTAssertNil(result.workNote)
        XCTAssertEqual(result.pauseSegments, [])
        XCTAssertEqual(stub.activeSession?.id, result.id)
    }

    func test_start_shouldPropagateError_whenRepositoryFails() async {
        // Given
        struct StubError: Error {}
        let stub = FocusSessionRepositoryStub()
        stub.error = StubError()
        let sut = DefaultFocusSessionUseCase(repository: stub)

        // When / Then
        do {
            _ = try await sut.start(duration: 1500)
            XCTFail("Repository 에러가 전파되어야 합니다")
        } catch {
            XCTAssertTrue(error is StubError)
        }
    }

    // MARK: - pause / resume

    func test_pause_shouldAccumulateElapsedAndAppendOpenSegment_whenActive() async throws {
        // Given
        let (sut, stub, clock) = makeSUT()
        let session = try await sut.start(duration: 1500)
        clock.advance(by: 120)

        // When
        let result = try await sut.pause(sessionId: session.id)

        // Then
        XCTAssertEqual(result.status, .paused)
        XCTAssertEqual(result.accumulatedElapsed, 120)
        XCTAssertEqual(result.pauseSegments, [
            .init(pausedAt: session.startedAt.addingTimeInterval(120), resumedAt: nil)
        ])
        XCTAssertNil(result.completedAt)
        XCTAssertEqual(stub.activeSession?.status, .paused)
    }

    func test_pause_shouldThrowInvalidStatus_whenAlreadyPaused() async throws {
        // Given: 이미 paused — 재-pause 시 segment 중복·누적 이중 계산 방지
        let (sut, _, clock) = makeSUT()
        let session = try await sut.start(duration: 1500)
        clock.advance(by: 30)
        _ = try await sut.pause(sessionId: session.id)

        // When / Then
        await assertThrowsFocusSessionError(.invalidStatus) {
            _ = try await sut.pause(sessionId: session.id)
        }
    }

    func test_pause_shouldThrowNoActiveSession_whenNoSession() async {
        // Given
        let (sut, _, _) = makeSUT()

        // When / Then
        await assertThrowsFocusSessionError(.noActiveSession) {
            _ = try await sut.pause(sessionId: UUID())
        }
    }

    func test_resume_shouldCloseLastSegment_whenPaused() async throws {
        // Given
        let (sut, stub, clock) = makeSUT()
        let session = try await sut.start(duration: 1500)
        clock.advance(by: 120)
        _ = try await sut.pause(sessionId: session.id)
        clock.advance(by: 30)

        // When
        let result = try await sut.resume(sessionId: session.id)

        // Then: segment가 닫히고 pause 시간은 누적에 포함되지 않음
        XCTAssertEqual(result.status, .active)
        XCTAssertEqual(result.accumulatedElapsed, 120)
        XCTAssertEqual(result.pauseSegments, [
            .init(
                pausedAt: session.startedAt.addingTimeInterval(120),
                resumedAt: session.startedAt.addingTimeInterval(150)
            )
        ])
        XCTAssertEqual(stub.activeSession?.status, .active)
    }

    func test_resume_shouldThrowInvalidStatus_whenActive() async throws {
        // Given: pause 없이 바로 resume
        let (sut, _, _) = makeSUT()
        let session = try await sut.start(duration: 1500)

        // When / Then
        await assertThrowsFocusSessionError(.invalidStatus) {
            _ = try await sut.resume(sessionId: session.id)
        }
    }

    // MARK: - end

    func test_end_shouldMarkCancelledAndDropWorkNote_whenElapsedUnder60Seconds() async throws {
        // Given
        let (sut, stub, clock) = makeSUT()
        let session = try await sut.start(duration: 1500)
        clock.advance(by: 58)

        // When
        let result = try await sut.end(sessionId: session.id, workNote: "버려질 메모")

        // Then: 1분 미만은 기록 제외
        XCTAssertEqual(result.status, .cancelled)
        XCTAssertNil(result.workNote)
        XCTAssertEqual(result.accumulatedElapsed, 58)
        XCTAssertEqual(result.completedAt, session.startedAt.addingTimeInterval(58))
        XCTAssertEqual(stub.activeSession?.status, .cancelled)
    }

    func test_end_shouldMarkCompletedAndSaveWorkNote_whenElapsedOver60SecondsWithoutPause() async throws {
        // Given: pause 이력이 없어도 startedAt부터 누적되어야 함 (spec 의사코드 버그 회귀 방지)
        let (sut, _, clock) = makeSUT()
        let session = try await sut.start(duration: 1500)
        clock.advance(by: 62)

        // When
        let result = try await sut.end(sessionId: session.id, workNote: "메모")

        // Then
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.workNote, "메모")
        XCTAssertEqual(result.accumulatedElapsed, 62)
    }

    func test_end_shouldMarkCompleted_whenElapsedExactly60Seconds() async throws {
        // Given: 경계값 — 정확히 60초는 completed
        let (sut, _, clock) = makeSUT()
        let session = try await sut.start(duration: 1500)
        clock.advance(by: 60)

        // When
        let result = try await sut.end(sessionId: session.id, workNote: "경계")

        // Then
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.workNote, "경계")
    }

    func test_end_shouldAccumulateOnlyRunningTime_whenPausedAndResumedThreeTimes() async throws {
        // Given: run 30 → pause 10 → run 40 → pause 5 → run 20 → pause 7 → run 15
        let (sut, _, clock) = makeSUT()
        let session = try await sut.start(duration: 1500)
        let plan: [(run: TimeInterval, pause: TimeInterval)] = [(30, 10), (40, 5), (20, 7)]
        for step in plan {
            clock.advance(by: step.run)
            _ = try await sut.pause(sessionId: session.id)
            clock.advance(by: step.pause)
            _ = try await sut.resume(sessionId: session.id)
        }
        clock.advance(by: 15)

        // When
        let result = try await sut.end(sessionId: session.id, workNote: "회고")

        // Then: pause 22초 제외한 순수 running 시간만 누적
        XCTAssertEqual(result.accumulatedElapsed, 105)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.workNote, "회고")
        XCTAssertEqual(result.pauseSegments.count, 3)
        XCTAssertTrue(result.pauseSegments.allSatisfy { $0.resumedAt != nil })
    }

    func test_end_shouldNotAccumulateExtra_whenEndedWhilePaused() async throws {
        // Given: run 90 → pause → 50초 방치 후 paused 상태에서 end
        let (sut, _, clock) = makeSUT()
        let session = try await sut.start(duration: 1500)
        clock.advance(by: 90)
        _ = try await sut.pause(sessionId: session.id)
        clock.advance(by: 50)

        // When
        let result = try await sut.end(sessionId: session.id, workNote: "메모")

        // Then: pause 시간은 누적되지 않고, completedAt은 실제 종료 시각
        XCTAssertEqual(result.accumulatedElapsed, 90)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.completedAt, session.startedAt.addingTimeInterval(140))
    }

    func test_end_shouldThrowNoActiveSession_whenNoSession() async {
        // Given
        let (sut, _, _) = makeSUT()

        // When / Then
        await assertThrowsFocusSessionError(.noActiveSession) {
            _ = try await sut.end(sessionId: UUID(), workNote: nil)
        }
    }

    func test_end_shouldThrowSessionMismatch_whenSessionIdDoesNotMatch() async throws {
        // Given
        let (sut, _, _) = makeSUT()
        _ = try await sut.start(duration: 1500)

        // When / Then
        await assertThrowsFocusSessionError(.sessionMismatch) {
            _ = try await sut.end(sessionId: UUID(), workNote: nil)
        }
    }

    // MARK: - Helpers

    private func makeSUT() -> (
        sut: DefaultFocusSessionUseCase,
        stub: FocusSessionRepositoryStub,
        clock: FakeClock
    ) {
        let clock = FakeClock()
        let stub = FocusSessionRepositoryStub()
        let sut = DefaultFocusSessionUseCase(repository: stub, now: { clock.now })
        return (sut, stub, clock)
    }

    private func assertThrowsFocusSessionError(
        _ expected: FocusSessionError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("\(expected) 에러가 발생해야 합니다", file: file, line: line)
        } catch let error as FocusSessionError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("예상치 못한 에러: \(error)", file: file, line: line)
        }
    }
}

/// 테스트에서 시각을 결정론적으로 전진시키기 위한 가짜 시계
private nonisolated final class FakeClock: @unchecked Sendable {
    private(set) var now: Date

    init(start: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.now = start
    }

    func advance(by seconds: TimeInterval) {
        now.addTimeInterval(seconds)
    }
}
