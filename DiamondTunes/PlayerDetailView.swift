//
//  PlayerDetailView.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/15/26.
//

import SwiftUI
import SwiftData

struct PlayerDetailView: View {
    @Bindable var player: Player
    @State private var newSongInput = ""

    var body: some View {
        Form {
            Section("Player") {
                TextField("Name", text: $player.name)
            }

            Section("Add Walkup Song") {
                TextField("Paste Spotify track link or URI", text: $newSongInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Add Song") {
                    addSong()
                }
                .disabled(cleanedSongInput.isEmpty)
            }

            Section("Walkup Songs") {
                if player.songs.isEmpty {
                    Text("No songs yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(player.songs, id: \.self) { song in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayTitle(for: song))
                                .font(.body)

                            Text(song)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deleteSongs)
                }
            }
        }
        .navigationTitle(player.name.isEmpty ? "Player" : player.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cleanedSongInput: String {
        newSongInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addSong() {
        let value = cleanedSongInput
        guard !value.isEmpty else { return }

        player.songs.append(value)
        newSongInput = ""
    }

    private func deleteSongs(at offsets: IndexSet) {
        player.songs.remove(atOffsets: offsets)
    }

    private func displayTitle(for song: String) -> String {
        if song.contains("spotify:track:") {
            return "Spotify Track URI"
        } else if song.contains("open.spotify.com/track/") {
            return "Spotify Track Link"
        } else {
            return "Custom Song Entry"
        }
    }
}
