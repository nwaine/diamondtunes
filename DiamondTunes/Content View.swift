//
//  Content View.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/15/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Player.battingOrder) private var players: [Player]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DiamondTunes")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Walk-Up Manager")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spotify")
                            .font(.title3)
                            .fontWeight(.semibold)

                        if let token = spotifyAuth.accessToken, !token.isEmpty {
                            Label("Connected to Spotify", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button {
                                spotifyAuth.startLogin()
                            } label: {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Connect Spotify")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            }

                            if spotifyAuth.isAuthenticating {
                                Text("Waiting for Spotify login...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        GameModeView()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Game Mode")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    HStack {
                        Text("Roster")
                            .font(.title2)
                            .fontWeight(.bold)

                        Spacer()

                        Button {
                            addPlayer()
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.bold)
                                .padding(10)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }

                    if players.isEmpty {
                        VStack(spacing: 12) {
                            Text("No players yet")
                                .font(.headline)

                            Text("Add your first player to start building your lineup.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        VStack(spacing: 12) {
                            ForEach(players) { player in
                                NavigationLink {
                                    PlayerDetailView(player: player)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(player.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)

                                            Text("\(player.songs.count) song\(player.songs.count == 1 ? "" : "s")")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text("#\(player.battingOrder + 1)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .onAppear {
                normalizeBattingOrderIfNeeded()
            }
        }
    }

    private func addPlayer() {
        let newPlayer = Player(
            name: "New Player",
            songs: [],
            battingOrder: players.count
        )
        context.insert(newPlayer)

        do {
            try context.save()
            print("Player saved")
        } catch {
            print("Failed to save player: \(error)")
        }
    }

    private func normalizeBattingOrderIfNeeded() {
        let sorted = players.sorted { $0.battingOrder < $1.battingOrder }
        for (index, player) in sorted.enumerated() {
            if player.battingOrder != index {
                player.battingOrder = index
            }
        }

        do {
            try context.save()
        } catch {
            print("Failed to normalize batting order: \(error)")
        }
    }
}
