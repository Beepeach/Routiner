import UIKit

// MARK: - DefaultDIContainer

/// `DIContainer`의 기본 구현체.
///
/// 싱글톤 스타일 의존성(Repository, Storage 등)은 `lazy var`로,
/// 화면마다 새 인스턴스가 필요한 경우(ViewModel, Coordinator)는 Factory Method로 제공한다.
/// 현재는 비어있으며 이슈 #3 이후부터 Repository/UseCase가 등록된다.
final class DefaultDIContainer: DIContainer {

    // MARK: - Initialization

    init() {}

    // MARK: - Dependencies (이슈 #3 이후 등록)
    //
    // 예시:
    //   lazy var focusSessionRepository: FocusSessionRepository = {
    //       DefaultFocusSessionRepository(storage: focusSessionStorage)
    //   }()
    //
    //   private lazy var focusSessionStorage: FocusSessionStorage = {
    //       InMemoryFocusSessionStorage()
    //   }()

    // MARK: - Factory Methods (이슈 #4 이후 등록)
    //
    // 예시:
    //   func makeFocusViewModel() -> FocusViewModel {
    //       FocusViewModel(
    //           startFocusSessionUseCase: makeStartFocusSessionUseCase(),
    //           cancelFocusSessionUseCase: makeCancelFocusSessionUseCase()
    //       )
    //   }
}
