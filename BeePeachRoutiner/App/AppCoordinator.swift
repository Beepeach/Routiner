import UIKit

// MARK: - AppCoordinator

/// 앱 진입점 Coordinator. `SceneDelegate`가 window에 연결한다.
///
/// UITabBarController에 Timer/Activity/Settings 3개 탭을 구성하고,
/// 각 탭의 화면 흐름은 자식 Coordinator에 위임한다.
/// 탭 아이콘/타이틀/순서 같은 탭 구성 책임은 이 클래스가 단독으로 소유한다.
final class AppCoordinator: Coordinator {

    // MARK: - Properties

    private let tabBarController: UITabBarController
    var childCoordinators: [Coordinator] = []

    private let diContainer: DIContainer

    // MARK: - Initialization

    init(
        tabBarController: UITabBarController,
        diContainer: DIContainer
    ) {
        self.tabBarController = tabBarController
        self.diContainer = diContainer
    }

    // swiftlang/swift#87316 워크어라운드: MainActor 기본 격리가 합성하는 isolated deinit이
    // 동기 컨텍스트 해제 시(XCTest 등) 런타임 크래시를 일으켜 nonisolated로 고정한다.
    nonisolated deinit {}

    // MARK: - Coordinator

    func start() {
        let timerNavigationController = UINavigationController()
        timerNavigationController.tabBarItem = UITabBarItem(
            title: "Timer",
            image: UIImage(systemName: "timer"),
            tag: 0
        )
        // 의존성 조립은 Composition Root 인 여기서 — 자식 Coordinator 는 완성된 객체만 소비한다.
        let timerCoordinator = TimerCoordinator(
            navigationController: timerNavigationController,
            viewModel: diContainer.makeFocusViewModel()
        )
        addChild(timerCoordinator)
        timerCoordinator.start()

        let activityNavigationController = UINavigationController()
        activityNavigationController.tabBarItem = UITabBarItem(
            title: "Activity",
            image: UIImage(systemName: "chart.bar"),
            tag: 1
        )
        let activityCoordinator = ActivityCoordinator(
            navigationController: activityNavigationController
        )
        addChild(activityCoordinator)
        activityCoordinator.start()

        let settingsNavigationController = UINavigationController()
        settingsNavigationController.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            tag: 2
        )
        let settingsCoordinator = SettingsCoordinator(
            navigationController: settingsNavigationController
        )
        addChild(settingsCoordinator)
        settingsCoordinator.start()

        tabBarController.viewControllers = [
            timerNavigationController,
            activityNavigationController,
            settingsNavigationController
        ]
    }
}
