import Foundation

struct SpotifyTrack: Decodable, Identifiable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum?
    let uri: String?

    var artistLine: String {
        artists.map(\.name).joined(separator: ", ")
    }

    var artworkURL: URL? {
        guard let urlString = album?.images.first?.url else { return nil }
        return URL(string: urlString)
    }
}

struct SpotifyArtist: Decodable {
    let name: String
}

struct SpotifyAlbum: Decodable {
    let images: [SpotifyImage]
}

struct SpotifyImage: Decodable {
    let url: String
}

struct SpotifyTrackSearchResponse: Decodable {
    let tracks: SpotifyTrackSearchPage
}

struct SpotifyTrackSearchPage: Decodable {
    let items: [SpotifyTrack]
}

struct SpotifyDevicesResponse: Decodable {
    let devices: [SpotifyDevice]
}

struct SpotifyDevice: Decodable, Identifiable {
    let id: String
    let isActive: Bool
    let isRestricted: Bool
    let name: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case id
        case isActive = "is_active"
        case isRestricted = "is_restricted"
        case name
        case type
    }

    var isPhoneLike: Bool {
        let normalized = type.lowercased()
        return normalized == "smartphone" || normalized == "phone"
    }
}
