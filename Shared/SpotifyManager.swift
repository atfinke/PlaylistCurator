//
//  SpotifyManager.swift
//  SpotifyAddToPlaylist
//
//  Created by Andrew Finke on 9/18/18.
//  Copyright © 2018 Andrew Finke. All rights reserved.
//

import Combine
import SwiftUI

#if os(iOS)
import UIKit
import WatchConnectivity
#elseif os(watchOS)
import WatchKit
import WatchConnectivity
#elseif os(macOS)
import Cocoa
#endif

@MainActor
@Observable
class SpotifyManager: NSObject {

    // MARK: - Types

    enum ManagerError: Error {
        case notAuthenticated
        case invalidResponse
        case invalidNowPlayingImageResponse
        case badRequest
    }

    struct NowPlayingState {
        let trackName: String
        let trackURI: String
        let trackImage: Image?
        let playlistURI: String?
    }

    // MARK: - Auth Properties -

    let authenticationManager = AuthenticationManager()

    private var isPreventingDoubleClick = false {
        didSet {
            if isPreventingDoubleClick {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    self.isPreventingDoubleClick = false
                }
            }
        }
    }

    // MARK: - State Properties -

    public var objectWillChange = ObservableObjectPublisher()

    public var nowPlayingPlaylistName = "-"
    public var nowPlayingTrackName = "-"
    public var nowPlayingTrackImage: Image?

    private var nowPlayingPlaylistURI: String?
    private var nowPlayingTrackURI: String?

    // MARK: - Initalization -

    override init() {
        super.init()

#if os(iOS) || os(watchOS)
        startWatchSession()
#endif

        Task {
            repeat {
                do {
                    _ = try await updateNowPlaying()
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    print("#function: " + error.localizedDescription)
                }
                try? await Task.sleep(for: .seconds(1))
            } while(!Task.isCancelled)
        }
    }

    // MARK: - User Actions -

    func keepTrack() async {
        guard !isPreventingDoubleClick else { return }
        isPreventingDoubleClick = true

        do {
            var success = false
            if try await postSkipTrack() {
                if try await putSeekTrack() {
                    success = true
                }
            }
            self.userActionCompleted(successfully: success)
        } catch {
            print("#function: " + error.localizedDescription)
            self.userActionCompleted(successfully: false)
        }
    }

    func removeTrack() async {
        guard !isPreventingDoubleClick else { return }
        isPreventingDoubleClick = true

        do {
            let success = try await deleteTrackFromPlaylist()
            if success {
                if try await postSkipTrack() {
                    _ = try? await self.putSeekTrack()
                }
            }
            self.userActionCompleted(successfully: success)
        } catch {
            print("#function: " + error.localizedDescription)
            self.userActionCompleted(successfully: false)
        }
    }

    nonisolated func reloadNowPlaying() async {
        do {
            let success = try await updateNowPlaying()
            self.userActionCompleted(successfully: success)
        } catch {
            print("#function: " + error.localizedDescription)
            self.userActionCompleted(successfully: false)
        }
    }

    nonisolated private func userActionCompleted(successfully success: Bool) {
        Task { @MainActor in
#if os(iOS)
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
#elseif os(watchOS)
            if success {
                WKInterfaceDevice.current().play(.success)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
#endif
        }
    }

    // MARK: - Spotify API -

    @discardableResult
    private func updateNowPlaying(delay: Double = 0.0) async throws -> Bool {
        func set(playlist: String, track: String) {
            nowPlayingTrackName = track
            nowPlayingPlaylistName = playlist
        }

        try await Task.sleep(for: .seconds(delay))

        let nowPlayingState = try await getNowPlayingState()
        guard let playlistURI = nowPlayingState.playlistURI else {
            set(playlist: "-", track: "-")
            return false
        }

        let playlistName = try await getPlaylistName(for: playlistURI)

        self.nowPlayingTrackURI = nowPlayingState.trackURI
        self.nowPlayingPlaylistURI = playlistURI
        self.nowPlayingTrackImage = nowPlayingState.trackImage
        set(playlist: playlistName, track: nowPlayingState.trackName)
        return true
    }

    nonisolated func getNowPlayingState() async throws -> NowPlayingState {
        var request = try await authenticationManager.apiURLRequest(for: "/v1/me/player/currently-playing/")
        request.httpMethod = "GET"

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
              let item = json["item"] as? [String: Any],
              let isPlaying = json["is_playing"] as? Bool,
              let trackName = item["name"] as? String,
              let trackURI = item["uri"] as? String,
              let context = json["context"] as? [String: Any],
              let contextType = context["type"] as? String,
              let contextURI = context["uri"] as? String,
              let album = item["album"] as? [String: Any],
              let images = album["images"] as? [[String: Any]],
              let imageURLString = images.first?["url"] as? String,
              let imageURL = URL(string: imageURLString),
              contextType == "playlist" else {
            throw ManagerError.invalidResponse
        }

#if os(macOS)
        if !isPlaying {
            await NSApplication.shared.hide(nil)
        }
#endif

        let nowPlayingTrackURI = await self.nowPlayingTrackURI
        if trackURI == nowPlayingTrackURI {
            return await .init(trackName: trackName,
                               trackURI: trackURI,
                               trackImage: self.nowPlayingTrackImage,
                               playlistURI: contextURI)
        }

#if os(watchOS)
        return .init(trackName: trackName,
                     trackURI: trackURI,
                     trackImage: nil,
                     playlistURI: contextURI)
#else

        var trackImage: Image?
        do {
            trackImage = try await fetchImage(for: imageURL)

        } catch {
            print(error)
        }
        return .init(trackName: trackName,
                     trackURI: trackURI,
                     trackImage: trackImage,
                     playlistURI: contextURI)
#endif
    }

    nonisolated func fetchImage(for url: URL) async throws -> Image {
        let (data, _) = try await URLSession.shared.data(from: url)

#if os(macOS)
        guard let nativeImage = NSImage(data: data) else {
            throw ManagerError.invalidNowPlayingImageResponse
        }
        let image = Image(nsImage: nativeImage)
#else
        guard let nativeImage = UIImage(data: data) else {
            throw ManagerError.invalidNowPlayingImageResponse
        }
        let image = Image(uiImage: nativeImage)
#endif
        return image
    }

    nonisolated func getPlaylistName(for uri: String) async throws -> String {
        guard let playlistID = uri.components(separatedBy: ":").last else {
            throw ManagerError.badRequest
        }

        var request = try await authenticationManager.apiURLRequest(for: "/v1/playlists/" + playlistID)
        request.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
              let playlistName = json["name"] as? String else {
            throw ManagerError.invalidResponse
        }
        return playlistName
    }

    nonisolated private func deleteTrackFromPlaylist() async throws -> Bool {
        guard let playlistID = await nowPlayingPlaylistURI?.components(separatedBy: ":").last,
              let trackURI = await nowPlayingTrackURI else {
            throw ManagerError.badRequest
        }

        let state = try await getNowPlayingState()
        guard trackURI == state.trackURI else {
            throw ManagerError.badRequest
        }

        var request = try await authenticationManager.apiURLRequest(for: "/v1/playlists/\(playlistID)/tracks")
        request.httpMethod = "DELETE"
        let param = ["tracks": [["uri": trackURI]]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: param)
        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
            return true
        } else {
            return false
        }
    }

    nonisolated private func postSkipTrack() async throws -> Bool {
        var request = try await authenticationManager.apiURLRequest(for: "/v1/me/player/next")
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 204 {
            Task {
                try await self.updateNowPlaying(delay: 0.5)
            }
            return true
        } else {
            return false
        }
    }

    nonisolated private func putSeekTrack() async throws -> Bool {
        var request = try await authenticationManager.apiURLRequest(for: "/v1/me/player/seek", queryItems: [
            .init(name: "position_ms", value: "30000")
        ])
        request.httpMethod = "PUT"
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 204 {
            return true
        } else {
            return false
        }
    }
}

#if os(iOS) || os(watchOS)
extension SpotifyManager: WCSessionDelegate {
    func startWatchSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate -

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task.detached {
            await self.authenticationManager.set("_", forKey: "force_update")
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {}
#elseif os(watchOS)
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task.detached {
            await self.authenticationManager.didReceive(applicationContext: applicationContext)
        }
    }
#endif

}
#endif
