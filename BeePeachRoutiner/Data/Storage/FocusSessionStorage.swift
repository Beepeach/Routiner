import Foundation

// MARK: - FocusSessionStorage

/// `FocusSession` 영속화 백엔드의 추상화.
protocol FocusSessionStorage: Sendable {
    func save(_ session: FocusSession) async throws
    func fetchActive() async throws -> FocusSession?
    func update(_ session: FocusSession) async throws
    /// Repository 인터페이스로는 노출하지 않는, 테스트/디버깅용 전체 조회.
    func fetchAll() async throws -> [FocusSession]
}
