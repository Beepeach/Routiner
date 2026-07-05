import UIKit

// MARK: - DefaultDIContainer

final class DefaultDIContainer: DIContainer {

    // MARK: - Singleton Dependencies

    private let focusSessionStorage: FocusSessionStorage

    let focusSessionRepository: FocusSessionRepository

    // MARK: - Initialization

    init() {
        let storage = InMemoryFocusSessionStorage()
        self.focusSessionStorage = storage
        self.focusSessionRepository = DefaultFocusSessionRepository(storage: storage)
    }

    // swiftlang/swift#87316 워크어라운드: MainActor 기본 격리가 합성하는 isolated deinit이
    // 동기 컨텍스트 해제 시(XCTest 등) 런타임 크래시를 일으켜 nonisolated로 고정한다.
    nonisolated deinit {}

    // MARK: - Factory Methods

    func makeFocusSessionUseCase() -> FocusSessionUseCase {
        DefaultFocusSessionUseCase(repository: focusSessionRepository)
    }

    func makeFocusViewModel() -> FocusViewModel {
        FocusViewModel(useCase: makeFocusSessionUseCase())
    }
}
