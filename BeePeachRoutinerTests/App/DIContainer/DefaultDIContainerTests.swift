import XCTest
@testable import BeePeachRoutiner

final class DefaultDIContainerTests: XCTestCase {

    // MARK: - Singleton 동작

    /// protocol existential의 identity는 박싱으로 인해 신뢰할 수 없어 행동으로 검증한다.
    func test_focusSessionRepository_shouldShareStorage_whenAccessedTwice() async throws {
        // Given
        let sut = DefaultDIContainer()
        let session = FocusSession(
            id: UUID(),
            startedAt: Date(),
            duration: 1500,
            goal: nil,
            status: .active,
            completedAt: nil
        )

        // When
        try await sut.focusSessionRepository.save(session)

        // Then
        let fetched = try await sut.focusSessionRepository.fetchActive()
        XCTAssertEqual(fetched?.id, session.id)
    }

    // MARK: - Full flow

    func test_makeFocusSessionUseCase_shouldExecuteStartAndCompleteFlow_whenInvokedFromContainer() async throws {
        // Given
        let sut = DefaultDIContainer()
        let useCase = sut.makeFocusSessionUseCase()
        let goal = FocusSessionGoal(title: "DI Flow Test")

        // When
        let started = try await useCase.start(duration: 1500, goal: goal)
        let completed = try await useCase.complete(sessionId: started.id)

        // Then
        XCTAssertEqual(started.status, .active)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.id, started.id)
        XCTAssertNotNil(completed.completedAt)

        let active = try await sut.focusSessionRepository.fetchActive()
        XCTAssertNil(active, "complete 후에는 활성 세션이 없어야 합니다")
    }
}
