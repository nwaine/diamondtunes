//
//  player.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/15/26.
//

import Foundation
import SwiftData

struct WalkupSong: Codable, Hashable {
    var spotifyInput: String
    var startTimeSeconds: Double

    init(spotifyInput: String, startTimeSeconds: Double = 0) {
        self.spotifyInput = spotifyInput
        self.startTimeSeconds = startTimeSeconds
    }
}

@Model
final class Player {
    var name: String
    var songs: [WalkupSong]
    var battingOrder: Int

    init(name: String, songs: [WalkupSong] = [], battingOrder: Int = 0) {
        self.name = name
        self.songs = songs
        self.battingOrder = battingOrder
    }
}
