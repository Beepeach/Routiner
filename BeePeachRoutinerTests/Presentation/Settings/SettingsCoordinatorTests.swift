import XCTest
@testable import BeePeachRoutiner

@MainActor
final class SettingsCoordinatorTests: XCTestCase {

    // MARK: - start

    func test_start_shouldSetSettingsViewControllerAsRoot_whenCalled() {
        // Given
        let navigationController = UINavigationController()
        let sut = SettingsCoordinator(navigationController: navigationController)

        // When
        sut.start()

        // Then
        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first is SettingsViewController)
    }

    // MARK: - SettingsViewController

    func test_viewDidLoad_shouldShowAppNameAndVersion_whenLoaded() {
        // Given
        let viewController = SettingsViewController()

        // 버전이 바뀌어도 테스트가 깨지지 않도록 기대값을 하드코딩하지 않고
        // 화면과 동일한 소스(Bundle.main)로부터 계산해 비교한다.
        let info = Bundle.main.infoDictionary
        let expectedAppName = info?["CFBundleName"] as? String ?? "BeePeach Routiner"
        let expectedVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0"

        // When
        viewController.loadViewIfNeeded()

        // Then
        XCTAssertEqual(viewController.title, "Settings")
        XCTAssertEqual(viewController.appNameLabel.text, expectedAppName)
        XCTAssertEqual(viewController.versionLabel.text, "v\(expectedVersion)")
        XCTAssertFalse(viewController.appNameLabel.text?.isEmpty ?? true)
    }
}
