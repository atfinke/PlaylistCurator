//
//  ButtonContentView.swift
//  PlaylistCurator WatchKit Extension
//
//  Created by Andrew Finke on 7/20/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import SwiftUI

struct ButtonContentView: View {
    let imageName: String
    let color: Color
    var body: some View {
        Image(systemName: imageName)
            .resizable()
            .frame(width: 36, height: 36)
            .foregroundColor(.white)
            .frame(minWidth: 0,
                   maxWidth: .infinity,
                   minHeight: 0,
                   maxHeight: .infinity)
    }
}
