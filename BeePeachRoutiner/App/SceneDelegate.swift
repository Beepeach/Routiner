import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - Properties

    private var diContainer: DIContainer?
    private var appCoordinator: AppCoordinator?

    // MARK: - UIWindowSceneDelegate

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // 앱 조립 루트: DIContainer → NavigationController → AppCoordinator
        let diContainer = DefaultDIContainer()
        let navigationController = UINavigationController()
        let appCoordinator = AppCoordinator(
            navigationController: navigationController,
            diContainer: diContainer
        )

        self.diContainer = diContainer
        self.appCoordinator = appCoordinator

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window

        appCoordinator.start()
    }
}
