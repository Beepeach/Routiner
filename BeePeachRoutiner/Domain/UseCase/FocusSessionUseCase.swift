import Foundation

/// Focus Session 라이프사이클을 관장하는 UseCase
///
/// - 동작:
///   - `start(duration:goal:)`: 새 세션 생성 후 저장 (status = .active, completedAt = nil)
///   - `pause(sessionId:)`: 활성 세션 일시정지 — 마지막 running 구간을 accumulatedElapsed에 누적하고 열린 PauseSegment 추가
///   - `resume(sessionId:)`: 일시정지된 세션 재개 — 마지막 PauseSegment를 닫음
///   - `complete(sessionId:)`: 진행 중인 세션 완료 처리 (status = .completed, completedAt = now)
///   - `cancel(sessionId:)`: 진행 중인 세션 취소 처리 (status = .cancelled, completedAt = now)
/// - Throws:
///   - `FocusSessionError.noActiveSession`: 활성 세션이 존재하지 않을 때
///   - `FocusSessionError.sessionMismatch`: 활성 세션 id와 요청 sessionId가 다를 때
///   - `FocusSessionError.invalidStatus`: pause는 active, resume은 paused 상태에서만 허용
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
    private let now: @Sendable () -> Date

    init(
        repository: FocusSessionRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.now = now
    }

    func start(duration: TimeInterval, goal: FocusSessionGoal?) async throws -> FocusSession {
        let session = FocusSession(
            id: UUID(),
            startedAt: now(),
            duration: duration,
            goal: goal,
            status: .active,
            completedAt: nil
        )
        try await repository.save(session)
        return session
    }

    func pause(sessionId: UUID) async throws -> FocusSession {
        var session = try await activeSession(matching: sessionId)
        guard session.status == .active else {
            throw FocusSessionError.invalidStatus
        }
        let pausedAt = now()
        session.accumulatedElapsed += pausedAt.timeIntervalSince(session.lastRunStartedAt)
        session.pauseSegments.append(.init(pausedAt: pausedAt, resumedAt: nil))
        session.status = .paused
        try await repository.update(session)
        return session
    }

    func resume(sessionId: UUID) async throws -> FocusSession {
        var session = try await activeSession(matching: sessionId)
        guard session.status == .paused else {
            throw FocusSessionError.invalidStatus
        }
        // 불변식: .paused는 pause()에서만 만들어지므로 pauseSegments는 비어있지 않다
        session.pauseSegments[session.pauseSegments.count - 1].resumedAt = now()
        session.status = .active
        try await repository.update(session)
        return session
    }

    func complete(sessionId: UUID) async throws -> FocusSession {
        try await transition(sessionId: sessionId, to: .completed, markCompletedAt: true)
    }

    func cancel(sessionId: UUID) async throws -> FocusSession {
        try await transition(sessionId: sessionId, to: .cancelled, markCompletedAt: true)
    }

    /// 활성 세션을 조회하고 sessionId 일치를 검증한다.
    private func activeSession(matching sessionId: UUID) async throws -> FocusSession {
        guard let session = try await repository.fetchActive() else {
            throw FocusSessionError.noActiveSession
        }
        guard session.id == sessionId else {
            throw FocusSessionError.sessionMismatch
        }
        return session
    }

    /// 활성 세션의 상태를 다른 상태로 전이시킨다.
    /// `markCompletedAt`: complete/cancel 처럼 종료 시점 기록이 필요할 때 true.
    private func transition(
        sessionId: UUID,
        to status: FocusSessionStatus,
        markCompletedAt: Bool
    ) async throws -> FocusSession {
        var session = try await activeSession(matching: sessionId)
        session.status = status
        if markCompletedAt {
            session.completedAt = now()
        }
        try await repository.update(session)
        return session
    }
}

private extension FocusSession {
    /// 마지막 running 구간의 시작 시각. pause 이력이 없으면 startedAt.
    var lastRunStartedAt: Date { pauseSegments.last?.resumedAt ?? startedAt }
}
