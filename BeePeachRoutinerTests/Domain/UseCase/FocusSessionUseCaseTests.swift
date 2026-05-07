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
