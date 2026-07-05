import Foundation

enum FocusSessionError: Error, Equatable, Sendable {
    case noActiveSession  // 활성 세션이 존재하지 않음
    case sessionMismatch  // 활성 세션 id와 요청 sessionId 불일치
    case invalidStatus  // 현재 상태에서 허용되지 않는 전이 (pause는 active, resume은 paused에서만)
}
