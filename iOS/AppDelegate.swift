//
//  AppDelegate.swift
//  PlaylistCurator
//
//  Created by Andrew Finke on 7/20/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import UIKit
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Properties

    var window: UIWindow?
    let manager = SpotifyManager()

    // MARK: - Did Launch -

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .black
        
        let controller = PCViewController(rootView: ContentView(manager: manager))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        self.window = window

        manager.reloadNowPlaying()
        return true
    }

    // MARK: - Open URL -

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        manager.handleOpenURL(components)
        return true
    }

}

