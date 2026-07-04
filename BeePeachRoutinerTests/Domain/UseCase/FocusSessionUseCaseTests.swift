import XCTest
@testable import BeePeachRoutiner

final class FocusSessionUseCaseTests: XCTestCase {

    // MARK: - start

    func test_start_shouldReturnActiveSession_whenCalled() async throws {
        // Given
        let stub = FocusSessionRepositoryStub()
        let sut = DefaultFocusSessionUseCase(repository: stub)
        let goal = FocusSessionGoal(title: "Test")

        // When
        let result = try await sut.start(duration: 1500, goal: goal)

        // Then
        XCTAssertEqual(result.status, .active)
        XCTAssertNil(result.completedAt)
        XCTAssertEqual(result.duration, 1500)
        XCTAssertEqual(result.goal?.title, "Test")
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
            _ = try await sut.start(duration: 1500, goal: nil)
            XCTFail("Repository 에러가 전파되어야 합니다")
        } catch {
            XCTAssertTrue(error is StubError)
        }
    }

    // MARK: - complete

    func test_complete_shouldMarkSessionCompleted_whenActiveSessionExists() async throws {
        // Given
        let stub = FocusSessionRepositoryStub()
        let initial = makeActiveSession()
        stub.activeSession = initial
        let sut = DefaultFocusSessionUseCase(repository: stub)

        // When
        let result = try await sut.complete(sessionId: initial.id)

        // Then
        XCTAssertEqual(result.status, .completed)
        XCTAssertNotNil(result.completedAt)
        XCTAssertEqual(stub.activeSession?.status, .completed)
        XCTAssertNotNil(stub.activeSession?.completedAt)
    }

    func test_complete_shouldThrowNoActiveSession_whenNoActiveSession() async {
        // Given
        let stub = FocusSessionRepositoryStub()
        stub.activeSession = nil
        let sut = DefaultFocusSessionUseCase(repository: stub)

        // When / Then
        await assertThrowsFocusSessionError(.noActiveSession) {
            _ = try await sut.complete(sessionId: UUID())
        }
    }

    func test_complete_shouldThrowSessionMismatch_whenSessionIdDoesNotMatch() async {
        // Given
        let stub = FocusSessionRepositoryStub()
        stub.activeSession = makeActiveSession()
        let sut = DefaultFocusSessionUseCase(repository: stub)

        // When / Then
        await assertThrowsFocusSessionError(.sessionMismatch) {
            _ = try await sut.complete(sessionId: UUID())
        }
    }

    // MARK: - pause / resume

    func test_pause_shouldAccumulateElapsedAndAppendOpenSegment_whenActive() async throws {
        // Given
        let (sut, stub, clock) = makeSUT()
        let session = try await sut.start(duration: 1500, goal: nil)
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
        let session = try await sut.start(duration: 1500, goal: nil)
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
        let session = try await sut.start(duration: 1500, goal: nil)
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
        let session = try await sut.start(duration: 1500, goal: nil)

        // When / Then
        await assertThrowsFocusSessionError(.invalidStatus) {
            _ = try await sut.resume(sessionId: session.id)
        }
    }

    // MARK: - cancel

    func test_cancel_shouldMarkSessionCancelled_whenActiveSessionExists() async throws {
        // Given
        let stub = FocusSessionRepositoryStub()
        let initial = makeActiveSession()
        stub.activeSession = initial
        let sut = DefaultFocusSessionUseCase(repository: stub)

        // When
        let result = try await sut.cancel(sessionId: initial.id)

        // Then
        XCTAssertEqual(result.status, .cancelled)
        XCTAssertNotNil(result.completedAt)
        XCTAssertEqual(stub.activeSession?.status, .cancelled)
        XCTAssertNotNil(stub.activeSession?.completedAt)
    }

    func test_cancel_shouldThrowNoActiveSession_whenNoActiveSession() async {
        // Given
        let stub = FocusSessionRepositoryStub()
        stub.activeSession = nil
        let sut = DefaultFocusSessionUseCase(repository: stub)

        // When / Then
        await assertThrowsFocusSessionError(.noActiveSession) {
            _ = try await sut.cancel(sessionId: UUID())
        }
    }

    func test_cancel_shouldThrowSessionMismatch_whenSessionIdDoesNotMatch() async {
        // Given
        let stub = FocusSessionRepositoryStub()
        stub.activeSession = makeActiveSession()
        let sut = DefaultFocusSessionUseCase(repository: stub)

        // When / Then
        await assertThrowsFocusSessionError(.sessionMismatch) {
            _ = try await sut.cancel(sessionId: UUID())
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

    private func makeActiveSession() -> FocusSession {
        FocusSession(
            id: UUID(),
            startedAt: Date(),
            duration: 1500,
            goal: nil,
            status: .active,
            completedAt: nil
        )
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
private final class FakeClock: @unchecked Sendable {
    private(set) var now: Date

    init(start: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.now = start
    }

    func advance(by seconds: TimeInterval) {
        now.addTimeInterval(seconds)
    }
}
