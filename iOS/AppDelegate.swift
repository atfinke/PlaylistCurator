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
        let controller = UIHostingController(rootView: ContentView(manager: manager))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        self.window = window

        Task(priority: .userInitiated) {
            await manager.reloadNowPlaying()
        }
        return true
    }

    // MARK: - Open URL -

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        Task.detached {
            await self.manager.authenticationManager.handleOpenURL(components)
        }
        return true
    }

}
