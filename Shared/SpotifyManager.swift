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

class SpotifyManager: NSObject, ObservableObject {
    
    // MARK: - Auth Properties -
    
    static let defaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: "group.com.andrewfinke.test") else {
            fatalError()
        }
        return defaults
    }()
    
    private var authorizationCode: String? {
        get {
            return SpotifyManager.defaults.string(forKey: #function)
        }
        set {
            set(newValue as Any, forKey: #function)
        }
    }
    
    private var accessToken: String? {
        get {
            return SpotifyManager.defaults.string(forKey: #function)
        }
        set {
            set(newValue as Any, forKey: #function)
        }
    }
    
    private var accessTokenExpiration: Date? {
        get {
            return SpotifyManager.defaults.object(forKey: #function) as? Date
        }
        set {
            set(newValue as Any, forKey: #function)
        }
    }
    
    private var refreshToken: String? {
        get {
            return SpotifyManager.defaults.string(forKey: #function)
        }
        set {
            set(newValue as Any, forKey: #function)
        }
    }
    
    private func set(_ value: Any, forKey key: String) {
        SpotifyManager.defaults.set(value, forKey: key)
        print(#function + ": " + key)
        #if os(iOS)
        let contextWorkaround = SpotifyManager.defaults.dictionaryRepresentation()
        do {
            try WCSession.default.updateApplicationContext(contextWorkaround)
        } catch {
            print(error)
        }
        #endif
    }
    
    private var isAccessTokenValid: Bool {
        if accessToken != nil,
            let date = accessTokenExpiration,
            date.timeIntervalSinceNow > 60 {
            return true
        } else {
            return false
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
        
        Timer.scheduledTimer(withTimeInterval: 45.0,
                             repeats: true) { _ in
                                self.updateNowPlaying()
        }
        updateNowPlaying()
    }
    
    // MARK: - Get Authorization Code -
    
    private func requestAuthorizationCode () {
        guard !isAccessTokenValid else {
            updateNowPlaying()
            return
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "accounts.spotify.com"
        components.path = "/authorize"
        
        components.queryItems = authQueryItems(appending: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "user-modify-playback-state user-read-playback-state user-read-currently-playing playlist-modify-public playlist-modify-private"),
        ])
        
        guard let url = components.url else { fatalError() }
        
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.open(url,
                                      options: [:],
                                      completionHandler: nil)
        }
        #elseif os(watchOS)
        print("need ios auth")
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
    
    func handleOpenURL(_ components: URLComponents) {
        guard components.queryItems?.count == 1,
            let item = components.queryItems?.first,
            item.name == "code",
            let code = item.value else {
                // Invalid open url scheme
                return
        }
        authorizationCode = code
        requestAccessToken()
    }
    
    private func requestAccessToken(completion: ((String?) -> Void)? = nil) {
        if isAccessTokenValid, let token = accessToken {
            completion?(token)
            return
        }
        
        let additionalQueryItems: [URLQueryItem]
        if let token = refreshToken {
            additionalQueryItems = [
                URLQueryItem(name: "grant_type", value: "refresh_token"),
                URLQueryItem(name: "refresh_token", value: token)
            ]
        } else if let code = authorizationCode {
            additionalQueryItems = [
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "code", value: code)
            ]
        } else {
            requestAuthorizationCode()
            completion?(nil)
            return
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "accounts.spotify.com"
        components.path = "/api/token"
        
        components.queryItems = authQueryItems(appending: additionalQueryItems)
        
        guard let url = components.url else { fatalError() }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print(response as Any)
                print(error)
                // Failed to fetch access token
                completion?(nil)
            } else if let data = data {
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                guard let accessToken = json?["access_token"] as? String,
                    let expiresIn = json?["expires_in"] as? Int else {
                        // Invalid access token json
                        return
                }
                
                self.accessToken = accessToken
                self.accessTokenExpiration = Date(timeIntervalSinceNow: TimeInterval(expiresIn))
                self.refreshToken = (json?["refresh_token"] as? String) ?? self.refreshToken
                
                completion?(accessToken)
            }
        }
        task.resume()
    }
    
    // MARK: - User Actions -
    
    func keepTrack() {
        postSkipTrack(completion: { success in
            DispatchQueue.main.async {
                self.userActionCompleted(successfully: success)
            }
        })
    }
    
    func removeTrack() {
        deleteTrackFromPlaylist(completion: { success in
            DispatchQueue.main.async {
                if success {
                    self.postSkipTrack()
                }
                self.userActionCompleted(successfully: success)
            }
        })
    }

    func reloadNowPlaying() {
        updateNowPlaying { success in
            self.userActionCompleted(successfully: success)
        }
    }
    
    private func userActionCompleted(successfully success: Bool) {
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
    
    // MARK: - Spotify API -
    
    private func updateNowPlaying(delay: Double = 0.0, completion: ((Bool) -> Void)? = nil) {
        func set(playlist: String, track: String) {
            nowPlayingTrackName = track
            nowPlayingPlaylistName = playlist
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + delay) {
            self.getNowPlayingState { trackName, trackURI, trackImage, playlistURI  in
                guard let playlistURI = playlistURI else {
                    set(playlist: "-", track: "-")
                    completion?(false)
                    return
                }
                self.getPlaylistName(for: playlistURI) { playlistName in
                    guard let trackName = trackName,
                        let trackURI = trackURI,
                        let playlistName = playlistName else {
                            set(playlist: "-", track: "-")
                            completion?(false)
                            return
                    }
                    self.nowPlayingTrackURI = trackURI
                    self.nowPlayingPlaylistURI = playlistURI
                    self.nowPlayingTrackImage = trackImage
                    set(playlist: playlistName, track: trackName)
                    completion?(true)
                }
            }
        }
    }
    
    func getNowPlayingState(completion: @escaping ((_ trackName: String?, _ trackURI: String?, _ trackImage: Image?, _ playlistURI: String?) -> Void)) {
        apiURLRequest(for: "/v1/me/player/currently-playing/") { request in
            guard var request = request else { return }
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
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
                    let durationMS = item["duration_ms"] as? Double,
                    contextType == "playlist" else {
                        completion(nil, nil, nil, nil)
                        return
                }
                
                #if os(macOS)
                DispatchQueue.main.async {
                    if isPlaying {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    } else {
                        NSApplication.shared.hide(nil)
                    }
                }
                #endif

                if trackURI == self.nowPlayingTrackURI {
                    completion(trackName,
                               trackURI,
                               self.nowPlayingTrackImage,
                               contextURI)
                    return
                } else {
                    let duration = durationMS / 1000
                    Timer.scheduledTimer(withTimeInterval: duration - 10, repeats: false) { _ in
                        self.updateNowPlaying()
                    }
                    Timer.scheduledTimer(withTimeInterval: duration + 10, repeats: false) { _ in
                        self.updateNowPlaying()
                    }
                    Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
                        self.updateNowPlaying()
                    }
                }
                
                self.fetchImage(for: imageURL) { trackImage in
                    completion(trackName,
                               trackURI,
                               trackImage,
                               contextURI)
                }
            }
            task.resume()
        }
    }
    
    func fetchImage(for url: URL, completion: @escaping ((Image?) -> Void)) {
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            
            #if os(macOS)
            guard let data = data, let nativeImage = NSImage(data: data) else {
                completion(nil)
                return
            }
            let image = Image(nsImage: nativeImage)
            #else
            guard let data = data, let nativeImage = UIImage(data: data) else {
                completion(nil)
                return
            }
            let image = Image(uiImage: nativeImage)
            #endif
            
            completion(image)
        }
        task.resume()
    }
    
    func getPlaylistName(for uri: String, completion: @escaping ((_ playlistName: String?) -> Void)) {
        guard let playlistID = uri.components(separatedBy: ":").last else {
            completion(nil)
            return
        }
        apiURLRequest(for: "/v1/playlists/" + playlistID) { request in
            guard var request = request else { return }
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { data, _, _ in
                guard let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
                    let playlistName = json["name"] as? String else {
                        completion(nil)
                        return
                }
                completion(playlistName)
            }
            task.resume()
        }
    }
    
    private func deleteTrackFromPlaylist(completion: @escaping ((Bool) -> Void)) {
        guard let playlistID = nowPlayingPlaylistURI?.components(separatedBy: ":").last,
            let trackURI = nowPlayingTrackURI else {
                completion(false)
                return
        }

        getNowPlayingState { _, currentTrackURI, _, _ in
            // make sure we can only delete current track
            guard trackURI == currentTrackURI else {
                completion(false)
                return
            }

            self.apiURLRequest(for: "/v1/playlists/\(playlistID)/tracks") { request in
                guard var request = request else { return }
                request.httpMethod = "DELETE"

                let param = ["tracks" : [["uri": trackURI]]]
                request.httpBody = try? JSONSerialization.data(withJSONObject: param)

                let task = URLSession.shared.dataTask(with: request) { data, response, _ in
                    if let httpResponse = response as? HTTPURLResponse,
                        httpResponse.statusCode == 200 {
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
                task.resume()
            }
        }
        

    }
    
    private func postSkipTrack(completion: ((Bool) -> Void)? = nil) {
        apiURLRequest(for: "/v1/me/player/next") { request in
            guard var request = request else { return }
            request.httpMethod = "POST"
            
            let task = URLSession.shared.dataTask(with: request) { _, response, _ in
                if let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 204 {
                    self.updateNowPlaying(delay: 0.5)
                    completion?(true)
                } else {
                    completion?(false)
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Helpers
    
    private func apiURLRequest(for path: String,
                               completion: @escaping ((URLRequest?) -> Void)) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.spotify.com"
        components.path = path
        
        guard let url = components.url else { fatalError() }
        var request = URLRequest(url: url)
        requestAccessToken { token in
            guard let token = token else {
                completion(nil)
                return
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            completion(request)
        }
    }
    
    private func authQueryItems(appending items: [URLQueryItem] = []) -> [URLQueryItem] {
        var queryItems = [
            URLQueryItem(name: "redirect_uri",
                         value: Configuration.shared.redirectURI),
            URLQueryItem(name: "client_id",
                         value: Configuration.shared.clientID),
            URLQueryItem(name: "client_secret",
                         value: Configuration.shared.clientSecret)
        ]
        queryItems.append(contentsOf: items)
        return queryItems
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
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        set("_", forKey: "force_update")
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    #elseif os(watchOS)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print(#function)
        for (key, value) in applicationContext {
            if key == "authorizationCode" {
                authorizationCode = value as? String
            } else if key == "accessToken" {
                accessToken = value as? String
            } else if key == "refreshToken" {
                refreshToken = value as? String
            } else if key == "accessTokenExpiration" {
                accessTokenExpiration = value as? Date
            }
        }
    }
    #endif
    
}
#endif
