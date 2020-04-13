//
//  ContentView.swift
//  PlaylistCurator macOS App
//
//  Created by Andrew Finke on 7/22/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import SwiftUI

struct AlbumView : View {
    var image: Image

    var body: some View {
        image.resizable()
            .frame(width: 60, height: 60)
    }
}

struct ButtonLabelView: View {
    let color: Color
    var body: some View {
        ZStack {
            Circle()
                        .foregroundColor(color)
                        .frame(width: 16)
        }

    }
}

struct ContentView: View {

    @ObservedObject var manager: SpotifyManager

    var body: some View {
        VStack {
            HStack {
                VStack {
                    Button(action: {
                        self.manager.keepTrack()
                    }, label: {
                        ButtonLabelView(color: Color(.sRGB,
                                                     red: 100.0 / 255.0,
                                                     green: 210.0 / 255.0,
                                                     blue: 110.0 / 255.0))
                    }).buttonStyle(PlainButtonStyle())
                    Spacer()
                    Button(action: {
                        self.manager.removeTrack()
                    }, label: {
                        ButtonLabelView(color: Color.red)
                    }).buttonStyle(PlainButtonStyle())
                }.frame(height: 40)
                    .padding(.trailing, 2)

                manager.nowPlayingTrackImage.map { image in
                    Button(action: {
                        self.manager.reloadNowPlaying()
                    }, label: {
                        AlbumView(image: image)
                    }).buttonStyle(PlainButtonStyle())

                }
            }
        }.padding()
    }
}
