//
//  FloatingWindowController.swift
//  PlaylistCurator macOS App
//
//  Created by Andrew Finke on 7/22/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import Cocoa
import SwiftUI

class FloatingWindowController: NSWindowController {

    // MARK: - Properties -

    let manager = SpotifyManager()

    // MARK: - View Life Cycle -

    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window = window, let contentView = window.contentView else { fatalError() }

        window.level = .floating
        window.titleVisibility = .hidden
        window.styleMask.remove(.titled)
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.collectionBehavior = .canJoinAllSpaces

        let hostingView = NSHostingView(rootView: ContentView(manager: SpotifyManager()))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(hostingView)

        let constraints = [
            hostingView.leadingAnchor
                .constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor
                .constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor
                .constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor
                .constraint(equalTo: contentView.bottomAnchor),
            contentView.heightAnchor.constraint(equalToConstant: 94),
            contentView.widthAnchor.constraint(equalToConstant: 120)
        ]
        NSLayoutConstraint.activate(constraints)
        let eventManager = NSAppleEventManager.shared()
        eventManager.setEventHandler(self,
                                     andSelector: #selector(handleEvent(_:)),
                                     forEventClass: AEEventClass(kInternetEventClass),
                                     andEventID: AEEventID(kAEGetURL))

        guard let bundleID = Bundle.main.bundleIdentifier else { fatalError() }
        LSSetDefaultHandlerForURLScheme("playlist-curator" as CFString,
                                        bundleID as CFString)
    }

    @objc func handleEvent(_ event: NSAppleEventDescriptor) {
        guard let descriptor = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)),
            let stringValue = descriptor.stringValue,
            let components = URLComponents(string: stringValue) else {
                return
        }
        manager.handleOpenURL(components)
    }
}
