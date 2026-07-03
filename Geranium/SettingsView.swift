import UIKit
import CoreLocation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // 直接启动位置模拟页面，彻底移除底部TabBar
        let storyboard = UIStoryboard(name: "LocSim", bundle: nil)
        guard let locSimVC = storyboard.instantiateInitialViewController() else {
            fatalError("LocSim module not found")
        }
        
        let navVC = UINavigationController(rootViewController: locSimVC)
        navVC.navigationBar.isHidden = true
        navVC.interactivePopGestureRecognizer?.isEnabled = false
        
        window.rootViewController = navVC
        window.makeKeyAndVisible()
        
        // 预申请位置权限
        CLLocationManager().requestWhenInUseAuthorization()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
