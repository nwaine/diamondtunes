//
//  SpotifyService.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/16/26.
//

import Foundation

enum SpotifyServiceError: Error {
    case invalidTrackID
    case invalidURL
    case badResponse
}

struct SpotifyService {
    static func fetchTrack(trackID: String, accessToken: String) async throws -> SpotifyTrack {
        guard !trackID.isEmpty else {
            throw SpotifyServiceError.invalidTrackID
        }

        guard let url = URL(string: "https://api.spotify.com/v1/tracks/\(trackID)") else {
            throw SpotifyServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw SpotifyServiceError.badResponse
        }

        return try JSONDecoder().decode(SpotifyTrack.self, from: data)
    }

    static func playTrack(trackURI: String, positionMS: Int = 0, accessToken: String) async throws {
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else {
            throw SpotifyServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "uris": [trackURI],
            "position_ms": positionMS
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyServiceError.badResponse
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let responseText = String(data: data, encoding: .utf8) ?? "No response body"
            print("Spotify playTrack failed")
            print("Status code: \(httpResponse.statusCode)")
            print("Response body: \(responseText)")
            throw SpotifyServiceError.badResponse
        }
    }

    static func seekToPosition(positionMS: Int, accessToken: String) async throws {
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/seek?position_ms=\(positionMS)") else {
            throw SpotifyServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyServiceError.badResponse
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let responseText = String(data: data, encoding: .utf8) ?? "No response body"
            print("Spotify seekToPosition failed")
            print("Status code: \(httpResponse.statusCode)")
            print("Response body: \(responseText)")
            throw SpotifyServiceError.badResponse
        }
    }

    static func pausePlayback(accessToken: String) async throws {
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/pause") else {
            throw SpotifyServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyServiceError.badResponse
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let responseText = String(data: data, encoding: .utf8) ?? "No response body"
            print("Spotify pausePlayback failed")
            print("Status code: \(httpResponse.statusCode)")
            print("Response body: \(responseText)")
            throw SpotifyServiceError.badResponse
        }
    }
    
    static func setPlaybackVolume(volumePercent: Int, accessToken: String) async throws {
        let clampedVolume = max(0, min(volumePercent, 100))

        guard let url = URL(string: "https://api.spotify.com/v1/me/player/volume?volume_percent=\(clampedVolume)") else {
            throw SpotifyServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyServiceError.badResponse
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let responseText = String(data: data, encoding: .utf8) ?? "No response body"
            print("Spotify setPlaybackVolume failed")
            print("Status code: \(httpResponse.statusCode)")
            print("Response body: \(responseText)")
            throw SpotifyServiceError.badResponse
        }
    }
}
