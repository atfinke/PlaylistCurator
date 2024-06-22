//
//  AppDelegate.swift
//  PlaylistCurator macOS App
//
//  Created by Andrew Finke on 7/22/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
