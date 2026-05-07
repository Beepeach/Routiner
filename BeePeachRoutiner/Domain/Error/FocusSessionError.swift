import Foundation

enum FocusSessionError: Error, Equatable {
    case noActiveSession  // 활성 세션이 존재하지 않음
    case sessionMismatch  // 활성 세션 id와 요청 sessionId 불일치
}
