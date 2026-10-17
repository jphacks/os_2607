/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A class that responds to application life cycle events.
*/

import UIKit
import NearbyInteraction

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        var isSupported: Bool
        if #available(iOS 16.0, *) {
            isSupported = NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
        } else {
            isSupported = NISession.isSupported
        }
        if !isSupported {
            print("unsupported device")
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let viewcontroller = storyboard.instantiateViewController(withIdentifier: "unsupportedDeviceMessage")
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = viewcontroller
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}
