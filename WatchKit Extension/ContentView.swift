//
//  ContentView.swift
//  PlaylistCurator WatchKit Extension
//
//  Created by Andrew Finke on 7/20/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import SwiftUI

@MainActor
struct ContentView: View {

    var manager = SpotifyManager()

    var body: some View {
        VStack {
            Button(action: {
                Task(priority: .userInitiated) {
                    await self.manager.keepTrack()
                }
            }, label: {
                ButtonContentView(imageName: "checkmark", color: .green)
            }).background(Color.green).cornerRadius(30)

            Button(action: {
                Task(priority: .userInitiated) {
                    await self.manager.removeTrack()
                }
            }, label: {
                ButtonContentView(imageName: "trash.circle.fill", color: .red)
            }).background(Color.red).cornerRadius(30)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarTitle(manager.nowPlayingTrackName)
    }
}
