import Foundation

/// Focus Session 라이프사이클을 관장하는 UseCase
///
/// - 동작:
///   - `start(duration:goal:)`: 새 세션 생성 후 저장 (status = .active, completedAt = nil)
///   - `complete(sessionId:)`: 활성 세션 완료 처리 (status = .completed, completedAt = Date())
///   - `cancel(sessionId:)`: 활성 세션 취소 처리 (status = .cancelled, completedAt = Date())
/// - Throws:
///   - `FocusSessionError.noActiveSession`: 활성 세션이 존재하지 않을 때 (complete/cancel)
///   - `FocusSessionError.sessionMismatch`: 활성 세션 id와 요청 sessionId가 다를 때 (complete/cancel)
///   - Repository 접근 실패 시 Error
protocol FocusSessionUseCase {
    func start(duration: TimeInterval, goal: FocusSessionGoal?) async throws -> FocusSession
    func complete(sessionId: UUID) async throws -> FocusSession
    func cancel(sessionId: UUID) async throws -> FocusSession
}

final class DefaultFocusSessionUseCase: FocusSessionUseCase {
    private let repository: FocusSessionRepository

    init(repository: FocusSessionRepository) {
        self.repository = repository
    }

    func start(duration: TimeInterval, goal: FocusSessionGoal?) async throws -> FocusSession {
        let session = FocusSession(
            id: UUID(),
            startedAt: Date(),
            duration: duration,
            goal: goal,
            status: .active,
            completedAt: nil
        )
        try await repository.save(session)
        return session
    }

    func complete(sessionId: UUID) async throws -> FocusSession {
        try await end(sessionId: sessionId, status: .completed)
    }

    func cancel(sessionId: UUID) async throws -> FocusSession {
        try await end(sessionId: sessionId, status: .cancelled)
    }

    private func end(sessionId: UUID, status: FocusSessionStatus) async throws -> FocusSession {
        guard var session = try await repository.fetchActive() else {
            throw FocusSessionError.noActiveSession
        }
        guard session.id == sessionId else {
            throw FocusSessionError.sessionMismatch
        }
        session.status = status
        session.completedAt = Date()
        try await repository.update(session)
        return session
    }
}
