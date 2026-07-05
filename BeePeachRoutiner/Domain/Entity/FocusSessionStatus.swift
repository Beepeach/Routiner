import Foundation

nonisolated enum FocusSessionStatus: Sendable, Equatable {
    case active
    case paused
    case completed
    case cancelled
}
