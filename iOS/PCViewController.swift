//
//  PCViewController.swift
//  PlaylistCurator
//
//  Created by Andrew Finke on 7/20/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import SwiftUI

class PCViewController: UIHostingController<ContentView> {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.backgroundColor = .black
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
