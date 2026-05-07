import UIKit

// MARK: - AppCoordinator

/// 앱 진입점 Coordinator. `SceneDelegate`가 window에 연결한다.
///
/// 현재는 플레이스홀더 `FocusViewController` 하나만 표시한다.
/// 이슈 #4에서 `FocusCoordinator`로 위임 구조가 확장될 예정이다.
final class AppCoordinator: Coordinator {

    // MARK: - Properties

    let navigationController: UINavigationController
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
        let focusViewController = FocusViewController()
        navigationController.setViewControllers([focusViewController], animated: false)
    }
}
