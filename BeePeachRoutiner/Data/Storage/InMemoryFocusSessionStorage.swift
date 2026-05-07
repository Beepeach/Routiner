import Foundation

// MARK: - InMemoryFocusSessionStorage

/// 메모리 기반 `FocusSessionStorage` 구현체.
///
/// 호출자는 모두 `async` 컨텍스트에서 접근해야 한다. 동기 컨텍스트에서 release되면
/// actor의 isolated deinit이 task hop을 시도하다 Swift 6 런타임 이슈로 메모리
/// corruption이 발생하므로, 테스트를 포함해 모든 진입점이 `async`여야 한다.
actor InMemoryFocusSessionStorage: FocusSessionStorage {

    // MARK: - State

    private var sessions: [UUID: FocusSession] = [:]

    // MARK: - Initialization

    init() {}

    // MARK: - FocusSessionStorage

    func save(_ session: FocusSession) async throws {
        sessions[session.id] = session
    }

    func fetchActive() async throws -> FocusSession? {
        sessions.values.first(where: { $0.status == .active })
    }

    func update(_ session: FocusSession) async throws {
        guard sessions[session.id] != nil else {
            throw StorageError.notFound
        }
        sessions[session.id] = session
    }

    func fetchAll() async throws -> [FocusSession] {
        Array(sessions.values)
    }
}
