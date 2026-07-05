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

        // 앱 조립 루트: DIContainer → TabBarController → AppCoordinator
        let diContainer = DefaultDIContainer()
        let tabBarController = UITabBarController()
        let appCoordinator = AppCoordinator(
            tabBarController: tabBarController,
            diContainer: diContainer
        )

        self.diContainer = diContainer
        self.appCoordinator = appCoordinator

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        self.window = window

        appCoordinator.start()
    }
}
