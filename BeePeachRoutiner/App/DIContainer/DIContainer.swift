import UIKit

// MARK: - DIContainer

/// 앱 전역 의존성 주입 컨테이너의 계약.
///
/// 싱글톤성 의존성은 프로퍼티로, 화면마다 새 인스턴스가 필요한 경우는 Factory Method로 노출한다.
protocol DIContainer: AnyObject, Sendable {
    var focusSessionRepository: FocusSessionRepository { get }

    func makeFocusSessionUseCase() -> FocusSessionUseCase
}
