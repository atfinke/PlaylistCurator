//
//  ContentView.swift
//  PlaylistCurator
//
//  Created by Andrew Finke on 7/20/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import SwiftUI
import Combine

@MainActor
struct ContentView: View {

    var manager = SpotifyManager()

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
            VStack {
                ZStack {
                    manager.nowPlayingTrackImage.map {
                        $0
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(16)
                    }
                    VStack {
                        Text(manager.nowPlayingTrackName)
                            .font(.system(size: 30, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                        Text(manager.nowPlayingPlaylistName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                }
                .padding()
                .contextMenu {
                    Button(action: {
                        Task(priority: .userInitiated) {
                            await self.manager.reloadNowPlaying()
                        }
                    }, label: {
                        HStack {
                            Text("Reload")
                            Image(systemName: "gobackward")
                        }
                    })
                }

                Spacer()

                Button(action: {
                    Task(priority: .userInitiated) {
                        await self.manager.keepTrack()
                    }
                }, label: {
                    ButtonContentView(imageName: "checkmark", color: .green)
                })

                Button(action: {
                    Task(priority: .userInitiated) {
                        await self.manager.removeTrack()
                    }
                }, label: {
                    ButtonContentView(imageName: "trash.circle.fill", color: .red)
                })

                Spacer()

            }

        }
        .background {
            Color.clear
                .background(.thinMaterial)
                .background {
                    if let image = manager.nowPlayingTrackImage {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .ignoresSafeArea()
                    }
                }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(), value: manager.nowPlayingTrackName)

    }
}

struct ButtonContentView: View {
    let imageName: String
    let color: Color
    var body: some View {
        ZStack {
            color
                .frame(maxHeight: 130)
                .cornerRadius(16)

            Image(systemName: imageName)
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)

    }
}
