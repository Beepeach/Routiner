import UIKit

// MARK: - FocusCoordinator

/// Focus 화면 흐름을 담당하는 Coordinator.
///
/// 현재는 `FocusViewController` 하나만 push 하지만, 추후 디지털 휠 모드/세션 결과 화면 등
/// Focus 도메인의 추가 화면이 생기면 이 Coordinator가 라우팅을 담당한다.
final class FocusCoordinator: Coordinator {

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
        let viewModel = diContainer.makeFocusViewModel()
        let viewController = FocusViewController(viewModel: viewModel)
        navigationController.setViewControllers([viewController], animated: false)
    }
}
