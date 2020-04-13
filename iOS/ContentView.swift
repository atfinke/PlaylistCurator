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
            .frame(width: 200, height: 200)
    }
}

struct ContentView: View {
    
    @ObservedObject var manager = SpotifyManager()
    
    var body: some View {
        return VStack {
            HStack {
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
            }.padding()
            
            Text(manager.nowPlayingPlaylistName)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(manager.nowPlayingTrackName)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding()
            
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
            
        }.background(Color.black)
    }
}
