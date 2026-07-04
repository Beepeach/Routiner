import Foundation

/// Focus Session 라이프사이클을 관장하는 UseCase
///
/// - 동작:
///   - `start(duration:goal:)`: 새 세션 생성 후 저장 (status = .active, completedAt = nil)
///   - `pause(sessionId:)`: 활성 세션 일시정지 — 마지막 running 구간을 accumulatedElapsed에 누적하고 열린 PauseSegment 추가
///   - `resume(sessionId:)`: 일시정지된 세션 재개 — 마지막 PauseSegment를 닫음
///   - `end(sessionId:workNote:)`: 세션 종료 — accumulatedElapsed 60초 미만이면 .cancelled(기록 제외), 이상이면 .completed
/// - Throws:
///   - `FocusSessionError.noActiveSession`: 활성 세션이 존재하지 않을 때
///   - `FocusSessionError.sessionMismatch`: 활성 세션 id와 요청 sessionId가 다를 때
///   - `FocusSessionError.invalidStatus`: pause는 active, resume은 paused 상태에서만 허용
///   - Repository 접근 실패 시 Error
protocol FocusSessionUseCase: Sendable {
    func start(duration: TimeInterval, goal: FocusSessionGoal?) async throws -> FocusSession
    func pause(sessionId: UUID) async throws -> FocusSession
    func resume(sessionId: UUID) async throws -> FocusSession
    func end(sessionId: UUID, workNote: String?) async throws -> FocusSession
}

final class DefaultFocusSessionUseCase: FocusSessionUseCase {
    /// 이 시간 미만의 세션은 종료 시 기록에서 제외(.cancelled)된다.
    private static let minimumCompletedElapsed: TimeInterval = 60

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

    func end(sessionId: UUID, workNote: String?) async throws -> FocusSession {
        var session = try await activeSession(matching: sessionId)
        let endedAt = now()
        // active면 마지막 running 구간을 누적. paused면 pause 시점에 이미 누적됨.
        if session.status == .active {
            session.accumulatedElapsed += endedAt.timeIntervalSince(session.lastRunStartedAt)
        }
        if session.accumulatedElapsed < Self.minimumCompletedElapsed {
            session.status = .cancelled
            session.workNote = nil  // 1분 미만은 작업 기록 제외
        } else {
            session.status = .completed
            session.workNote = workNote
        }
        session.completedAt = endedAt
        try await repository.update(session)
        return session
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
}

private extension FocusSession {
    /// 마지막 running 구간의 시작 시각. pause 이력이 없으면 startedAt.
    var lastRunStartedAt: Date { pauseSegments.last?.resumedAt ?? startedAt }
}
