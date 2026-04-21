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

    static func searchTracks(query: String, accessToken: String) async throws -> [SpotifyTrack] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "20")
        ]

        guard let url = components?.url else {
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

        return try JSONDecoder().decode(SpotifySearchResponse.self, from: data).tracks.items
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
}
