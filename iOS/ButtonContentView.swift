//
//  ButtonContentView.swift
//  PlaylistCurator
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
            .frame(width: 60, height: 60)
            .foregroundColor(.white)
            .frame(width: 340, height: 160)
            .background(color)
            .cornerRadius(32)
    }
}
