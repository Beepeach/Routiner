import XCTest
@testable import BeePeachRoutiner

@MainActor
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

    func test_makeFocusSessionUseCase_shouldExecuteStartAndEndFlow_whenInvokedFromContainer() async throws {
        // Given
        let sut = DefaultDIContainer()
        let useCase = sut.makeFocusSessionUseCase()

        // When: 실제 시계 기준 즉시 종료 → 60초 미만이므로 cancelled 로 기록 제외
        let started = try await useCase.start(duration: 1500)
        let ended = try await useCase.end(sessionId: started.id, workNote: "버려질 메모")

        // Then
        XCTAssertEqual(started.status, .active)
        XCTAssertEqual(ended.status, .cancelled)
        XCTAssertEqual(ended.id, started.id)
        XCTAssertNil(ended.workNote)
        XCTAssertNotNil(ended.completedAt)

        let active = try await sut.focusSessionRepository.fetchActive()
        XCTAssertNil(active, "end 후에는 활성 세션이 없어야 합니다")
    }
}
