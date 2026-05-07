import XCTest
@testable import BeePeachRoutiner

final class InMemoryFocusSessionStorageTests: XCTestCase {

    // MARK: - save

    func test_save_shouldStoreSession_whenCalled() async throws {
        // Given
        let sut = InMemoryFocusSessionStorage()
        let session = makeSession(status: .active)

        // When
        try await sut.save(session)

        // Then
        let all = try await sut.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, session.id)
    }

    func test_save_shouldOverwrite_whenSameIdSavedTwice() async throws {
        // Given
        let sut = InMemoryFocusSessionStorage()
        let id = UUID()
        let initial = makeSession(id: id, status: .active)
        let updated = makeSession(id: id, status: .completed)

        // When
        try await sut.save(initial)
        try await sut.save(updated)

        // Then
        let all = try await sut.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.status, .completed)
    }

    // MARK: - fetchActive

    func test_fetchActive_shouldReturnNil_whenNoSessionStored() async throws {
        // Given
        let sut = InMemoryFocusSessionStorage()

        // When
        let result = try await sut.fetchActive()

        // Then
        XCTAssertNil(result)
    }

    func test_fetchActive_shouldReturnActiveSession_whenSavedAsActive() async throws {
        // Given
        let sut = InMemoryFocusSessionStorage()
        let session = makeSession(status: .active)
        try await sut.save(session)

        // When
        let result = try await sut.fetchActive()

        // Then
        XCTAssertEqual(result?.id, session.id)
        XCTAssertEqual(result?.status, .active)
    }

    func test_fetchActive_shouldReturnNil_whenAllSessionsAreNotActive() async throws {
        // Given
        let sut = InMemoryFocusSessionStorage()
        try await sut.save(makeSession(status: .completed))
        try await sut.save(makeSession(status: .cancelled))

        // When
        let result = try await sut.fetchActive()

        // Then
        XCTAssertNil(result)
    }

    // MARK: - update

    func test_update_shouldThrowNotFound_whenSessionDoesNotExist() async {
        // Given
        let sut = InMemoryFocusSessionStorage()
        let session = makeSession(status: .completed)

        // When / Then
        do {
            try await sut.update(session)
            XCTFail("StorageError.notFound 가 발생해야 합니다")
        } catch let error as StorageError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    func test_update_shouldReplaceSession_whenSessionExists() async throws {
        // Given
        let sut = InMemoryFocusSessionStorage()
        let id = UUID()
        let initial = makeSession(id: id, status: .active)
        try await sut.save(initial)
        var modified = initial
        modified.status = .completed
        modified.completedAt = Date()

        // When
        try await sut.update(modified)

        // Then
        let fetched = try await sut.fetchAll().first
        XCTAssertEqual(fetched?.status, .completed)
        XCTAssertNotNil(fetched?.completedAt)
    }

    // MARK: - 동시성

    /// actor 격리가 동시 호출을 직렬화하는지 검증.
    /// 100개의 서로 다른 세션을 동시에 save 했을 때 모두 누락 없이 저장되어야 한다.
    func test_storage_shouldStoreAllSessions_whenAccessedConcurrently() async throws {
        // Given
        let sut = InMemoryFocusSessionStorage()
        let sessions = (0..<100).map { _ in makeSession(status: .completed) }

        // When
        await withTaskGroup(of: Void.self) { group in
            for session in sessions {
                group.addTask {
                    try? await sut.save(session)
                }
            }
        }

        // Then
        let all = try await sut.fetchAll()
        XCTAssertEqual(all.count, 100)
    }

    // MARK: - Helpers

    private func makeSession(
        id: UUID = UUID(),
        status: FocusSessionStatus
    ) -> FocusSession {
        FocusSession(
            id: id,
            startedAt: Date(),
            duration: 1500,
            goal: nil,
            status: status,
            completedAt: status == .active ? nil : Date()
        )
    }
}
