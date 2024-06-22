//
//  AuthenticationManager.swift
//  PlaylistCurator
//
//  Created by Andrew Finke on 6/22/24.
//  Copyright © 2024 Andrew Finke. All rights reserved.
//

@preconcurrency import Foundation
#if os(iOS)
import UIKit
import WatchConnectivity
#elseif os(watchOS)
import WatchKit
import WatchConnectivity
#elseif os(macOS)
import Cocoa
#endif

actor AuthenticationManager {

    enum AuthenticationError: Error {
        case notAuthenticated
        case invalidResponse
    }

    static let defaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: "group.com.andrewfinke.test") else {
            fatalError()
        }
        return defaults
    }()

    private let configuration = Configuration()

    private var isAccessTokenValid: Bool {
        if accessToken != nil,
            let date = accessTokenExpiration,
            date.timeIntervalSinceNow > 60 {
            return true
        } else {
            return false
        }
    }

    private var authorizationCode: String? {
        get {
            return Self.defaults.string(forKey: #function)
        }
        set {
            set(newValue as Any, forKey: #function)
        }
    }

    private var accessToken: String? {
        get {
            return Self.defaults.string(forKey: #function)
        }
        set {
            set(newValue as Any, forKey: #function)
        }
    }

    private var accessTokenExpiration: Date? {
        get {
            return Self.defaults.object(forKey: #function) as? Date
        }
        set {
            set(newValue as Any, forKey: #function)
        }
    }

    private var refreshToken: String? {
        get {
            return Self.defaults.string(forKey: #function)
        }
        set {
            set(newValue as Any, forKey: #function)
        }
    }

    func set(_ value: Any, forKey key: String) {
        Self.defaults.set(value, forKey: key)
        print(#function + ": " + key)
        #if os(iOS)
        let contextWorkaround = Self.defaults.dictionaryRepresentation()
        do {
            try WCSession.default.updateApplicationContext(contextWorkaround)
        } catch {
            print(error)
        }
        #endif
    }

    func apiURLRequest(for path: String, queryItems: [URLQueryItem] = []) async throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.spotify.com"
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else { fatalError() }
        var request = URLRequest(url: url)
        let token = try await requestAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    nonisolated private func authQueryItems(appending items: [URLQueryItem] = []) -> [URLQueryItem] {
        var queryItems = [
            URLQueryItem(name: "redirect_uri",
                         value: configuration.redirectURI),
            URLQueryItem(name: "client_id",
                         value: configuration.clientID),
            URLQueryItem(name: "client_secret",
                         value: configuration.clientSecret)
        ]
        queryItems.append(contentsOf: items)
        return queryItems
    }

    nonisolated private func requestAuthorizationCode () {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "accounts.spotify.com"
        components.path = "/authorize"

        components.queryItems = authQueryItems(appending: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "user-modify-playback-state user-read-playback-state user-read-currently-playing playlist-modify-public playlist-modify-private")
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
        Task.detached(priority: .userInitiated) {
            try? await self.requestAccessToken()
        }
    }

    private func requestAccessToken() async throws -> String {
        if isAccessTokenValid, let token = accessToken {
            return token
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
            throw AuthenticationError.notAuthenticated
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

        let (data, _) = try await URLSession.shared.data(for: request)

        let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let accessToken = json?["access_token"] as? String,
              let expiresIn = json?["expires_in"] as? Int else {
            // Invalid access token json
            throw AuthenticationError.invalidResponse
        }

        self.accessToken = accessToken
        self.accessTokenExpiration = Date(timeIntervalSinceNow: TimeInterval(expiresIn))
        self.refreshToken = (json?["refresh_token"] as? String) ?? self.refreshToken

        return accessToken
    }

#if os(watchOS)
    func didReceive(applicationContext: [String: Any]) {
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
