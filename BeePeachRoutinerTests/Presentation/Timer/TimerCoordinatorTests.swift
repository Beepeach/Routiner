import XCTest
@testable import BeePeachRoutiner

@MainActor
final class TimerCoordinatorTests: XCTestCase {

    // MARK: - start

    func test_start_shouldSetFocusViewControllerAsRoot_whenCalled() {
        // Given
        let navigationController = UINavigationController()
        let sut = TimerCoordinator(
            navigationController: navigationController,
            diContainer: DefaultDIContainer()
        )

        // When
        sut.start()

        // Then
        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first is FocusViewController)
    }
}
