import UIKit

// MARK: - AppCoordinator

/// 앱 진입점 Coordinator. `SceneDelegate`가 window에 연결한다.
///
/// 자식 `TimerCoordinator`에 Timer 탭 화면 흐름을 위임한다.
final class AppCoordinator: Coordinator {

    // MARK: - Properties

    private let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    private let diContainer: DIContainer

    // MARK: - Initialization

    init(
        navigationController: UINavigationController,
        diContainer: DIContainer
    ) {
        self.navigationController = navigationController
        self.diContainer = diContainer
    }

    // MARK: - Coordinator

    func start() {
        let timerCoordinator = TimerCoordinator(
            navigationController: navigationController,
            diContainer: diContainer
        )
        addChild(timerCoordinator)
        timerCoordinator.start()
    }
}
