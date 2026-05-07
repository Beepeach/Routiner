import Foundation

/// Focus Session 저장소 추상화
///
/// - Parameters:
///   - session: 저장/업데이트할 FocusSession
/// - Returns:
///   - save: 없음
///   - fetchActive: 현재 활성 중인 세션 (없으면 nil)
///   - update: 없음
/// - Throws: 저장소 접근 실패 시 Error
protocol FocusSessionRepository {
    func save(_ session: FocusSession) async throws
    func fetchActive() async throws -> FocusSession?
    func update(_ session: FocusSession) async throws
}
