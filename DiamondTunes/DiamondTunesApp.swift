//
//  DiamondTunesApp.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/15/26.
//

import SwiftUI
import SwiftData

@main
struct DiamondTunesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Player.self)
    }
}
