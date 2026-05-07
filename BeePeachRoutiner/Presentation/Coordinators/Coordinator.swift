import UIKit

// MARK: - Coordinator

/// 화면 전환 조정자의 공통 계약.
///
/// 모든 Coordinator는 자신이 소유하는 `navigationController`를 가지며,
/// 자식 Coordinator들의 라이프사이클을 `childCoordinators`로 추적한다.
/// 이를 통해 Coordinator 트리가 ARC 순환 없이 유지된다.
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    var childCoordinators: [Coordinator] { get set }

    func start()
}

extension Coordinator {

    // MARK: - Child Management

    /// 자식 Coordinator를 추가하여 메모리에 유지한다.
    func addChild(_ child: Coordinator) {
        childCoordinators.append(child)
    }

    /// 자식 Coordinator를 제거한다. 화면 dismiss/pop 시 호출한다.
    func removeChild(_ child: Coordinator) {
        childCoordinators.removeAll { $0 === child }
    }
}
