import XCTest
@testable import BeePeachRoutiner

@MainActor
final class ActivityCoordinatorTests: XCTestCase {

    // MARK: - start

    func test_start_shouldSetActivityViewControllerAsRoot_whenCalled() {
        // Given
        let navigationController = UINavigationController()
        let sut = ActivityCoordinator(navigationController: navigationController)

        // When
        sut.start()

        // Then
        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first is ActivityViewController)
    }

    // MARK: - ActivityViewController

    func test_viewDidLoad_shouldSetTitle_whenLoaded() {
        // Given
        let viewController = ActivityViewController()

        // When
        viewController.loadViewIfNeeded()

        // Then
        XCTAssertEqual(viewController.title, "Activity")
    }
}
