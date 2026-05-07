import Foundation

// MARK: - DefaultFocusSessionRepository

final class DefaultFocusSessionRepository: FocusSessionRepository {

    // MARK: - Dependencies

    private let storage: FocusSessionStorage

    // MARK: - Initialization

    init(storage: FocusSessionStorage) {
        self.storage = storage
    }

    // MARK: - FocusSessionRepository

    func save(_ session: FocusSession) async throws {
        try await storage.save(session)
    }

    func fetchActive() async throws -> FocusSession? {
        try await storage.fetchActive()
    }

    func update(_ session: FocusSession) async throws {
        try await storage.update(session)
    }
}
