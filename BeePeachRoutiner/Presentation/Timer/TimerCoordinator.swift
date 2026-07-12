import UIKit

// MARK: - TimerCoordinator

/// Timer 탭의 화면 흐름을 담당하는 Coordinator.
///
/// 현재는 `FocusViewController` 하나만 push 하지만, 추후 집중 대상 선택/세션 결과 화면 등
/// Timer 탭의 추가 화면이 생기면 이 Coordinator가 라우팅을 담당한다.
final class TimerCoordinator: Coordinator {

    // MARK: - Properties

    private let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    /// 조립이 끝난 ViewModel 을 주입받는다 — 의존성 조립(Composition Root)은 App 책임이고,
    /// Presentation 이 DIContainer 를 알면 레이어 역방향 의존이 생기기 때문.
    /// Timer 화면은 1회 생성이라 factory 없이 인스턴스로 충분하다.
    private let viewModel: FocusViewModel

    // MARK: - Initialization

    init(
        navigationController: UINavigationController,
        viewModel: FocusViewModel
    ) {
        self.navigationController = navigationController
        self.viewModel = viewModel
    }

    // swiftlang/swift#87316 워크어라운드: MainActor 기본 격리가 합성하는 isolated deinit이
    // 동기 컨텍스트 해제 시(XCTest 등) 런타임 크래시를 일으켜 nonisolated로 고정한다.
    nonisolated deinit {}

    // MARK: - Coordinator

    func start() {
        let viewController = FocusViewController(viewModel: viewModel)
        navigationController.setViewControllers([viewController], animated: false)
    }
}
