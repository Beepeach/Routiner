import Foundation
@testable import BeePeachRoutiner

/// `FocusSessionUseCase` 테스트용 Stub.
///
/// - 행동 검증: `startCallCount`, `cancelCallCount`, `completeCallCount`,
///   `lastCancelledSessionId` 등으로 호출 사실을 추적한다.
/// - 에러 주입: `startError`, `cancelError`, `completeError` 에 값을 세팅하면
///   해당 메서드가 그 에러를 던진다.
///
/// `@unchecked Sendable`: 단일 thread에서만 사용한다는 가정 하에 mutable 프로퍼티의
/// race 위험을 우리가 책임진다.
final class FocusSessionUseCaseStub: FocusSessionUseCase, @unchecked Sendable {

    // MARK: - Error Injection

    var startError: Error?
    var cancelError: Error?
    var completeError: Error?

    // MARK: - Error Injection (pause/resume)

    var pauseError: Error?
    var resumeError: Error?

    // MARK: - Call Tracking

    private(set) var startCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var completeCallCount = 0
    private(set) var lastPausedSessionId: UUID?
    private(set) var lastResumedSessionId: UUID?
    private(set) var lastCancelledSessionId: UUID?
    private(set) var lastCompletedSessionId: UUID?
    private(set) var lastStartedDuration: TimeInterval?
    private(set) var lastStartedGoal: FocusSessionGoal?

    // MARK: - FocusSessionUseCase

    func start(duration: TimeInterval, goal: FocusSessionGoal?) async throws -> FocusSession {
        startCallCount += 1
        lastStartedDuration = duration
        lastStartedGoal = goal
        if let error = startError { throw error }
        return FocusSession(
            id: UUID(),
            startedAt: Date(),
            duration: duration,
            goal: goal,
            status: .active,
            completedAt: nil
        )
    }

    func pause(sessionId: UUID) async throws -> FocusSession {
        pauseCallCount += 1
        lastPausedSessionId = sessionId
        if let error = pauseError { throw error }
        return ended(sessionId: sessionId, status: .paused)
    }

    func resume(sessionId: UUID) async throws -> FocusSession {
        resumeCallCount += 1
        lastResumedSessionId = sessionId
        if let error = resumeError { throw error }
        return ended(sessionId: sessionId, status: .active)
    }

    func complete(sessionId: UUID) async throws -> FocusSession {
        completeCallCount += 1
        lastCompletedSessionId = sessionId
        if let error = completeError { throw error }
        return ended(sessionId: sessionId, status: .completed)
    }

    func cancel(sessionId: UUID) async throws -> FocusSession {
        cancelCallCount += 1
        lastCancelledSessionId = sessionId
        if let error = cancelError { throw error }
        return ended(sessionId: sessionId, status: .cancelled)
    }

    // MARK: - Helpers

    private func ended(sessionId: UUID, status: FocusSessionStatus) -> FocusSession {
        // pause/resume 처럼 완료 시점을 기록하지 않는 전이는 completedAt 을 nil 로 둔다.
        let marksEnd = (status == .completed || status == .cancelled)
        return FocusSession(
            id: sessionId,
            startedAt: Date(),
            duration: 60,
            goal: nil,
            status: status,
            completedAt: marksEnd ? Date() : nil
        )
    }
}
