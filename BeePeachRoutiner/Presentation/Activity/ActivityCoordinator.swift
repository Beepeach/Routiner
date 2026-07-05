import UIKit

// MARK: - ActivityCoordinator

/// Activity 탭의 화면 흐름을 담당하는 Coordinator.
///
/// 현재는 placeholder 화면만 표시한다. 실제 활동 기록 화면이 생기면
/// DIContainer 의존성과 함께 라우팅을 확장한다.
final class ActivityCoordinator: Coordinator {

    // MARK: - Properties

    private let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    // MARK: - Initialization

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    // swiftlang/swift#87316 워크어라운드: MainActor 기본 격리가 합성하는 isolated deinit이
    // 동기 컨텍스트 해제 시(XCTest 등) 런타임 크래시를 일으켜 nonisolated로 고정한다.
    nonisolated deinit {}

    // MARK: - Coordinator

    func start() {
        let viewController = ActivityViewController()
        navigationController.setViewControllers([viewController], animated: false)
    }
}
