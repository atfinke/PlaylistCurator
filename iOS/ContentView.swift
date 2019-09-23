//
//  ContentView.swift
//  PlaylistCurator
//
//  Created by Andrew Finke on 7/20/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import SwiftUI
import Combine

struct AlbumView : View {
    var image: Image

    var body: some View {
        image
            .resizable()
            .frame(width: 340, height: 340)
            .cornerRadius(32)
            .padding(.top, 60)
    }
}

struct ContentView: View {

    @ObservedObject var manager = SpotifyManager()

    var body: some View {
        return VStack {
            manager.nowPlayingTrackImage.map {
                AlbumView(image: $0).contextMenu {
                    Button(action: {
                        self.manager.reloadNowPlaying()
                    }, label: {
                        HStack {
                            Text("Reload")
                            Image(systemName: "gobackward")
                        }
                    })
                }
            }
            Text(manager.nowPlayingTrackName)

            Spacer()

            Button(action: {
                self.manager.keepTrack()
            }, label: {
                ButtonContentView(imageName:"checkmark", color: .green)
            }).padding(.bottom, 10)

            Button(action: {
                self.manager.removeTrack()
            }, label: {
                ButtonContentView(imageName:"trash.circle.fill", color: .red)
            }).padding(.bottom, 20)
            
        }.frame(minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity)
            .background(Color.black)
            .edgesIgnoringSafeArea(.all)
    }
}
