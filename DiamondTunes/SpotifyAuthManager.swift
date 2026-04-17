//
//  SpotifyAuthManager.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/16/26.
//

import Foundation
import Combine
import CryptoKit
import SwiftUI
import UIKit

@MainActor
final class SpotifyAuthManager: ObservableObject {
    static let shared = SpotifyAuthManager()

    let clientID = "b902dff1e3a54b2abf669fb09bbf2f2f"
    let redirectURI = "diamondtunes-login://callback"

    @Published var accessToken: String?
    @Published var isAuthenticating = false

    private var codeVerifier: String?

    func startLogin() {
        let verifier = Self.generateCodeVerifier()
        codeVerifier = verifier

        guard let challengeData = verifier.data(using: .utf8) else { return }
        let challenge = Data(SHA256.hash(data: challengeData))
            .base64URLEncodedString()

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: "user-read-playback-state user-modify-playback-state")
        ]

        guard let url = components?.url else { return }
        UIApplication.shared.open(url)
    }

    func handleCallback(url: URL) async {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
            let verifier = codeVerifier
        else {
            return
        }

        do {
            let token = try await exchangeCodeForToken(code: code, verifier: verifier)
            accessToken = token
            print("Spotify access token received")
        } catch {
            print("Failed to exchange code for token: \(error)")
        }
    }

    private func exchangeCodeForToken(code: String, verifier: String) async throws -> String {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier
        ]
        .map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }
        .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("Token exchange failed: \(responseBody)")
            throw URLError(.badServerResponse)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse.access_token
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let refresh_token: String?
        let scope: String
    }

    private static func generateCodeVerifier() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<64).compactMap { _ in chars.randomElement() })
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
