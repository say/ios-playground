//
//  AppDelegate.swift
//  SayPlayground
//
//  Created by Stephen Silber on 10/3/18.
//  Copyright © 2018 say. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    lazy var bubbleViewController = BubbleViewController(count: 50)
    lazy var particleViewController = ParticleSimulationViewController()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let rootViewController = PlaygroundOptionViewController()
        let navigationController = UINavigationController(rootViewController: rootViewController)
//        navigationController.isNavigationBarHidden = true
        navigationController.navigationBar.tintColor = UIColor(hexString: "11CC99")
        navigationController.navigationBar.barStyle = .blackTranslucent
        
        rootViewController.didSelectOption = { [unowned self] option in
            switch option {
            case .bubbleVisualization:
                navigationController.pushViewController(self.bubbleViewController, animated: true)
                
            case .particleSimulator:
                navigationController.pushViewController(self.particleViewController, animated: true)
            }
        }
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        return true
    }
    
    // MARK: Shortcut Items
    
    @discardableResult
    private func handleShortcutItem(_ item: UIApplicationShortcutItem) -> Bool {
        return false
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handleShortcutItem(shortcutItem))
    }
    

}

