import XCTest
@testable import BeePeachRoutiner

@MainActor
final class AppCoordinatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT() -> (sut: AppCoordinator, tabBarController: UITabBarController) {
        let tabBarController = UITabBarController()
        let sut = AppCoordinator(
            tabBarController: tabBarController,
            diContainer: DefaultDIContainer()
        )
        return (sut, tabBarController)
    }

    // MARK: - start

    func test_start_shouldSetThreeNavigationControllers_whenCalled() {
        // Given
        let (sut, tabBarController) = makeSUT()

        // When
        sut.start()

        // Then
        let viewControllers = tabBarController.viewControllers ?? []
        XCTAssertEqual(viewControllers.count, 3)
        XCTAssertTrue(viewControllers.allSatisfy { $0 is UINavigationController })
    }

    func test_start_shouldConfigureTabBarItems_whenCalled() {
        // Given
        let (sut, tabBarController) = makeSUT()

        // When
        sut.start()

        // Then
        let items = (tabBarController.viewControllers ?? []).map(\.tabBarItem)
        XCTAssertEqual(items.map { $0?.title }, ["Timer", "Activity", "Settings"])
        XCTAssertEqual(items.map { $0?.tag }, [0, 1, 2])
        // UIImage(systemName:) 동등 비교는 캐시 동작에 의존하는 비계약이라
        // 심볼 이미지 존재 여부만 검증한다.
        for item in items {
            XCTAssertNotNil(item?.image)
            XCTAssertEqual(item?.image?.isSymbolImage, true)
        }
    }

    func test_start_shouldAddThreeChildCoordinators_whenCalled() {
        // Given
        let (sut, _) = makeSUT()

        // When
        sut.start()

        // Then
        XCTAssertEqual(sut.childCoordinators.count, 3)
    }

    func test_start_shouldSetFocusViewControllerAsTimerTabRoot_whenCalled() {
        // Given
        let (sut, tabBarController) = makeSUT()

        // When
        sut.start()

        // Then
        let timerNavigationController = tabBarController.viewControllers?.first as? UINavigationController
        XCTAssertTrue(timerNavigationController?.viewControllers.first is FocusViewController)
    }

    // MARK: - 세션 상태 보존

    func test_selectedIndexSwitch_shouldPreserveFocusViewControllerInstance_whenReturningToTimerTab() {
        // Given
        let (sut, tabBarController) = makeSUT()
        sut.start()
        tabBarController.loadViewIfNeeded()

        let timerNavigationController = tabBarController.viewControllers?.first as? UINavigationController
        let focusViewController = timerNavigationController?.viewControllers.first

        // When: 다른 탭으로 전환했다가 Timer 탭으로 복귀
        tabBarController.selectedIndex = 1
        tabBarController.selectedIndex = 0

        // Then: 같은 인스턴스가 유지되어 세션 상태(타이머, ViewModel)가 보존된다
        XCTAssertNotNil(focusViewController)
        XCTAssertIdentical(timerNavigationController?.viewControllers.first, focusViewController)
    }
}
