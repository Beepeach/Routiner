import Foundation

nonisolated struct FocusSession: Sendable {
    /// pause/resume 한 구간의 이력. resumedAt이 nil이면 아직 일시정지 중.
    nonisolated struct PauseSegment: Equatable, Sendable {
        let pausedAt: Date
        var resumedAt: Date?
    }

    let id: UUID
    let startedAt: Date
    let duration: TimeInterval  // 초 단위
    var status: FocusSessionStatus
    var completedAt: Date?  // 진행 중에는 nil
    var accumulatedElapsed: TimeInterval = 0  // pause 제외 순수 running 시간
    var workNote: String?
    var pauseSegments: [PauseSegment] = []
}
