//
//  SpotifyModels.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/16/26.
//

import Foundation

struct SpotifyTrack: Decodable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
}

struct SpotifyArtist: Decodable {
    let name: String
}
