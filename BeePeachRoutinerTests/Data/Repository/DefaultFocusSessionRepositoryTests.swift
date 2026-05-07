import XCTest
@testable import BeePeachRoutiner

/// `InMemoryFocusSessionStorage`를 실제 콜래보레이터로 사용해
/// Repository → Storage 경유 흐름을 통합 검증한다.
final class DefaultFocusSessionRepositoryTests: XCTestCase {

    func test_repository_shouldRoundTripSession_whenSaveAndFetchActive() async throws {
        // Given
        let storage = InMemoryFocusSessionStorage()
        let sut = DefaultFocusSessionRepository(storage: storage)
        let session = makeSession(status: .active)

        // When
        try await sut.save(session)
        let fetched = try await sut.fetchActive()

        // Then
        XCTAssertEqual(fetched?.id, session.id)
        XCTAssertEqual(fetched?.status, .active)
    }

    func test_repository_shouldReflectStatusChange_whenUpdateCalled() async throws {
        // Given
        let storage = InMemoryFocusSessionStorage()
        let sut = DefaultFocusSessionRepository(storage: storage)
        var session = makeSession(status: .active)
        try await sut.save(session)

        // When
        session.status = .completed
        session.completedAt = Date()
        try await sut.update(session)

        // Then
        let active = try await sut.fetchActive()
        XCTAssertNil(active, "완료 처리된 세션은 fetchActive 결과에서 제외되어야 합니다")
    }

    func test_repository_shouldPropagateNotFound_whenUpdatingMissingSession() async {
        // Given
        let storage = InMemoryFocusSessionStorage()
        let sut = DefaultFocusSessionRepository(storage: storage)
        let unsaved = makeSession(status: .completed)

        // When / Then
        do {
            try await sut.update(unsaved)
            XCTFail("StorageError.notFound 가 전파되어야 합니다")
        } catch let error as StorageError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeSession(status: FocusSessionStatus) -> FocusSession {
        FocusSession(
            id: UUID(),
            startedAt: Date(),
            duration: 1500,
            goal: nil,
            status: status,
            completedAt: status == .active ? nil : Date()
        )
    }
}
