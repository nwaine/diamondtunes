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
    @StateObject private var spotifyAuth = SpotifyAuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(spotifyAuth)
                .tint(AppTheme.red)
                .onOpenURL { url in
                    Task {
                        await spotifyAuth.handleCallback(url: url)
                    }
                }
        }
        .modelContainer(for: Player.self)
    }
}
