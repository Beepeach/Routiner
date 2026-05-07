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

    // MARK: - Factory Methods

    func makeFocusSessionUseCase() -> FocusSessionUseCase {
        DefaultFocusSessionUseCase(repository: focusSessionRepository)
    }
}
