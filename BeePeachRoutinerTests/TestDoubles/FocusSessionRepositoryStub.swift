import Foundation
@testable import BeePeachRoutiner

/// 상태 기반 검증을 위한 FocusSessionRepository Stub.
/// `activeSession`을 직접 조작해 초기 상태를 세팅하고,
/// 테스트는 SUT 호출 후 같은 프로퍼티의 변화로 결과를 검증한다.
final class FocusSessionRepositoryStub: FocusSessionRepository {
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
