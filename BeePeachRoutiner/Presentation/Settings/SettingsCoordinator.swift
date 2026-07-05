import UIKit

// MARK: - SettingsCoordinator

/// Settings 탭의 화면 흐름을 담당하는 Coordinator.
///
/// 현재는 placeholder 화면만 표시한다. 실제 설정 항목이 생기면
/// DIContainer 의존성과 함께 라우팅을 확장한다.
final class SettingsCoordinator: Coordinator {

    // MARK: - Properties

    private let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    // MARK: - Initialization

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    // MARK: - Coordinator

    func start() {
        let viewController = SettingsViewController()
        navigationController.setViewControllers([viewController], animated: false)
    }
}
