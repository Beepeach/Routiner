import Foundation

enum FocusSessionStatus: Sendable, Equatable {
    case active
    case paused
    case completed
    case cancelled
}
