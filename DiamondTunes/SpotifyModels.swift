import Foundation

struct SpotifyTrack: Decodable, Hashable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]

    var artistLine: String {
        artists.map(\.name).joined(separator: ", ")
    }
}

struct SpotifyArtist: Decodable, Hashable {
    let name: String
}

struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyTrackPage
}

struct SpotifyTrackPage: Decodable {
    let items: [SpotifyTrack]
}
