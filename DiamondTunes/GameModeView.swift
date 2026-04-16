//
//  GameModeView.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/15/26.
//

import SwiftUI
import SwiftData

struct GameModeView: View {
    @Query(sort: \Player.battingOrder) private var players: [Player]
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Game Mode")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(editMode?.wrappedValue.isEditing == true
                         ? "Drag players into batting order."
                         : "Tap a player to trigger walk-up music.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            if players.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Text("No players in roster")
                            .font(.headline)

                        Text("Add players before starting game mode.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section("Lineup") {
                    ForEach(players) { player in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.black)

                                Text("\(player.battingOrder + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.name)
                                    .font(.headline)

                                Text("\(player.songs.count) song\(player.songs.count == 1 ? "" : "s")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if editMode?.wrappedValue.isEditing == true {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.tertiary)
                            } else {
                                Button {
                                    print("Play walkup for \(player.name)")
                                } label: {
                                    Image(systemName: "play.fill")
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: movePlayers)
                }
            }
        }
        .navigationTitle("Game Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    private func movePlayers(from source: IndexSet, to destination: Int) {
        var reordered = players
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, player) in reordered.enumerated() {
            player.battingOrder = index
        }

        try? context.save()
    }
}
