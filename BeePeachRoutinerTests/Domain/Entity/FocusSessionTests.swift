import XCTest
@testable import BeePeachRoutiner

final class FocusSessionTests: XCTestCase {
    func test_focusSession_shouldInitializeWithCorrectValues_whenCreated() {
        // Given
        let id = UUID()
        let startedAt = Date()
        let duration: TimeInterval = 1500
        let status: FocusSessionStatus = .active

        // When
        let session = FocusSession(
            id: id,
            startedAt: startedAt,
            duration: duration,
            status: status,
            completedAt: nil
        )

        // Then
        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.startedAt, startedAt)
        XCTAssertEqual(session.duration, duration)
        XCTAssertEqual(session.status, status)
        XCTAssertNil(session.completedAt)
        XCTAssertEqual(session.accumulatedElapsed, 0)
        XCTAssertNil(session.workNote)
        XCTAssertEqual(session.pauseSegments, [])
    }
}
