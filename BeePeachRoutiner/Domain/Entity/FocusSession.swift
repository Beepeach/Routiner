import Foundation

struct FocusSession: Sendable {
    let id: UUID
    let startedAt: Date
    let duration: TimeInterval  // 초 단위
    let goal: FocusSessionGoal?
    var status: FocusSessionStatus
    var completedAt: Date?  // 진행 중에는 nil
}
