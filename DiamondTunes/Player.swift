//
//  player.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/15/26.
//

import Foundation
import SwiftData

@Model
final class Player {
    var name: String
    var songs: [String]
    var battingOrder: Int

    init(name: String, songs: [String] = [], battingOrder: Int = 0) {
        self.name = name
        self.songs = songs
        self.battingOrder = battingOrder
    }
}
