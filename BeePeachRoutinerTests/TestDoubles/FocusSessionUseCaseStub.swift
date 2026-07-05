import Foundation
@testable import BeePeachRoutiner

/// `FocusSessionUseCase` 테스트용 Stub.
///
/// - 행동 검증: `startCallCount`, `endCallCount`, `lastEndedSessionId` 등으로
///   호출 사실을 추적한다.
/// - 에러 주입: `startError`, `endError` 등에 값을 세팅하면
///   해당 메서드가 그 에러를 던진다.
///
/// `@unchecked Sendable`: 단일 thread에서만 사용한다는 가정 하에 mutable 프로퍼티의
/// race 위험을 우리가 책임진다.
nonisolated final class FocusSessionUseCaseStub: FocusSessionUseCase, @unchecked Sendable {

    // MARK: - Error Injection

    var startError: Error?
    var endError: Error?

    // MARK: - Error Injection (pause/resume)

    var pauseError: Error?
    var resumeError: Error?

    // MARK: - Call Tracking

    private(set) var startCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0
    private(set) var endCallCount = 0
    private(set) var lastPausedSessionId: UUID?
    private(set) var lastResumedSessionId: UUID?
    private(set) var lastEndedSessionId: UUID?
    private(set) var lastEndedWorkNote: String?
    private(set) var lastStartedDuration: TimeInterval?

    // MARK: - FocusSessionUseCase

    func start(duration: TimeInterval) async throws -> FocusSession {
        startCallCount += 1
        lastStartedDuration = duration
        if let error = startError { throw error }
        return FocusSession(
            id: UUID(),
            startedAt: Date(),
            duration: duration,
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

    func end(sessionId: UUID, workNote: String?) async throws -> FocusSession {
        endCallCount += 1
        lastEndedSessionId = sessionId
        lastEndedWorkNote = workNote
        if let error = endError { throw error }
        return ended(sessionId: sessionId, status: .completed)
    }

    // MARK: - Helpers

    private func ended(sessionId: UUID, status: FocusSessionStatus) -> FocusSession {
        // pause/resume 처럼 완료 시점을 기록하지 않는 전이는 completedAt 을 nil 로 둔다.
        let marksEnd = (status == .completed || status == .cancelled)
        return FocusSession(
            id: sessionId,
            startedAt: Date(),
            duration: 60,
            status: status,
            completedAt: marksEnd ? Date() : nil
        )
    }
}
