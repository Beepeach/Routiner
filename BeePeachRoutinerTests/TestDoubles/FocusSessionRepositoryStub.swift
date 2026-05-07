import Foundation
@testable import BeePeachRoutiner

/// 상태 기반 검증용 Stub. `activeSession`을 직접 세팅하고 호출 후 같은 프로퍼티 변화로 검증한다.
/// `@unchecked Sendable`: 단일 thread에서만 사용되므로 mutable 프로퍼티의 race 위험을 우리가 책임진다.
final class FocusSessionRepositoryStub: FocusSessionRepository, @unchecked Sendable {
    var activeSession: FocusSession?
    var error: Error?

    func save(_ session: FocusSession) async throws {
        if let error { throw error }
        activeSession = session
    }

    func fetchActive() async throws -> FocusSession? {
        if let error { throw error }
        return activeSession
    }

    func update(_ session: FocusSession) async throws {
        if let error { throw error }
        activeSession = session
    }
}
