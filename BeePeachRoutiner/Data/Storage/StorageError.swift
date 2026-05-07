import Foundation

// MARK: - StorageError

/// 저장소 인프라 레이어에서 발생하는 에러. 도메인 규칙 위반(`FocusSessionError`)과 구분된다.
enum StorageError: Error, Equatable, Sendable {
    case notFound
}
