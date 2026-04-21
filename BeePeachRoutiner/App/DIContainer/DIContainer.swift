import UIKit

// MARK: - DIContainer

/// 앱 전역 의존성 주입 컨테이너의 계약.
///
/// 현재는 비어있으며, 이슈 #2(Domain)와 이슈 #3(Repository) 이후
/// Repository/UseCase/ViewModel 팩토리가 이 프로토콜에 추가된다.
protocol DIContainer: AnyObject {
    // 이슈 #2 이후 다음과 같은 멤버들이 추가될 예정이다.
    //
    //   var focusSessionRepository: FocusSessionRepository { get }
    //   func makeFocusViewModel() -> FocusViewModel
    //   func makeFocusCoordinator(
    //       navigationController: UINavigationController
    //   ) -> FocusCoordinator
}
