import Foundation

/// Focus Session 라이프사이클을 관장하는 UseCase
///
/// - 동작:
///   - `start(duration:goal:)`: 새 세션 생성 후 저장 (status = .active, completedAt = nil)
///   - `pause(sessionId:)`: 활성 세션 일시정지 (status = .paused, completedAt 변경 없음)
///   - `resume(sessionId:)`: 일시정지된 세션 재개 (status = .active, completedAt 변경 없음)
///   - `complete(sessionId:)`: 진행 중인 세션 완료 처리 (status = .completed, completedAt = Date())
///   - `cancel(sessionId:)`: 진행 중인 세션 취소 처리 (status = .cancelled, completedAt = Date())
/// - Throws:
///   - `FocusSessionError.noActiveSession`: 활성 세션이 존재하지 않을 때 (pause/resume/complete/cancel)
///   - `FocusSessionError.sessionMismatch`: 활성 세션 id와 요청 sessionId가 다를 때
///   - Repository 접근 실패 시 Error
protocol FocusSessionUseCase: Sendable {
    func start(duration: TimeInterval, goal: FocusSessionGoal?) async throws -> FocusSession
    func pause(sessionId: UUID) async throws -> FocusSession
    func resume(sessionId: UUID) async throws -> FocusSession
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

    func pause(sessionId: UUID) async throws -> FocusSession {
        try await transition(sessionId: sessionId, to: .paused, markCompletedAt: false)
    }

    func resume(sessionId: UUID) async throws -> FocusSession {
        try await transition(sessionId: sessionId, to: .active, markCompletedAt: false)
    }

    func complete(sessionId: UUID) async throws -> FocusSession {
        try await transition(sessionId: sessionId, to: .completed, markCompletedAt: true)
    }

    func cancel(sessionId: UUID) async throws -> FocusSession {
        try await transition(sessionId: sessionId, to: .cancelled, markCompletedAt: true)
    }

    /// 활성 세션의 상태를 다른 상태로 전이시킨다.
    /// `markCompletedAt`: complete/cancel 처럼 종료 시점 기록이 필요할 때 true, pause/resume 같은 일시 전이엔 false.
    private func transition(
        sessionId: UUID,
        to status: FocusSessionStatus,
        markCompletedAt: Bool
    ) async throws -> FocusSession {
        guard var session = try await repository.fetchActive() else {
            throw FocusSessionError.noActiveSession
        }
        guard session.id == sessionId else {
            throw FocusSessionError.sessionMismatch
        }
        session.status = status
        if markCompletedAt {
            session.completedAt = Date()
        }
        try await repository.update(session)
        return session
    }
}
