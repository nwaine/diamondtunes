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
    @Published var connectionStatusText: String?

    var isConnected: Bool {
        if let accessToken, !accessToken.isEmpty {
            return true
        }
        return false
    }

    private var codeVerifier: String?
    private let accessTokenKey = "spotify_access_token"
    private let refreshTokenKey = "spotify_refresh_token"
    private let expiryDateKey = "spotify_expiry_date"

    private init() {
        restoreSessionIfPossible()
    }

    func restoreSessionIfPossible() {
        if let expiry = UserDefaults.standard.object(forKey: expiryDateKey) as? Date,
           expiry > Date(),
           let storedToken = UserDefaults.standard.string(forKey: accessTokenKey),
           !storedToken.isEmpty {
            accessToken = storedToken
            connectionStatusText = "Connected to Spotify."
            return
        }

        guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey), !refreshToken.isEmpty else {
            return
        }

        Task {
            do {
                try await refreshAccessToken(refreshToken: refreshToken)
            } catch {
                print("Failed to restore Spotify session: \(error)")
            }
        }
    }

    func startLogin() {
        let verifier = Self.generateCodeVerifier()
        codeVerifier = verifier
        isAuthenticating = true

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
            isAuthenticating = false
            return
        }

        do {
            let tokenResponse = try await exchangeCodeForToken(code: code, verifier: verifier)
            persistSession(from: tokenResponse)
            print("Spotify access token received")
        } catch {
            print("Failed to exchange code for token: \(error)")
        }

        isAuthenticating = false
    }

    private func exchangeCodeForToken(code: String, verifier: String) async throws -> TokenResponse {
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

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func refreshAccessToken(refreshToken: String) async throws {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        .map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }
        .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("Refresh token failed: \(responseBody)")
            throw URLError(.badServerResponse)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let merged = TokenResponse(
            access_token: tokenResponse.access_token,
            token_type: tokenResponse.token_type,
            expires_in: tokenResponse.expires_in,
            refresh_token: tokenResponse.refresh_token ?? refreshToken,
            scope: tokenResponse.scope
        )
        persistSession(from: merged)
    }

    private func persistSession(from tokenResponse: TokenResponse) {
        accessToken = tokenResponse.access_token
        connectionStatusText = "Connected to Spotify."

        UserDefaults.standard.set(tokenResponse.access_token, forKey: accessTokenKey)
        if let refresh = tokenResponse.refresh_token {
            UserDefaults.standard.set(refresh, forKey: refreshTokenKey)
        }
        UserDefaults.standard.set(Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in)), forKey: expiryDateKey)
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let refresh_token: String?
        let scope: String?
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
