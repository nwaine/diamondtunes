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
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager

    @State private var newSongInput = ""
    @State private var newSongStartTimeText = "0:00"

    private let maxSongs = 3

    @State private var trackMetadata: [String: SpotifyTrack] = [:]
    @State private var failedSongs: Set<String> = []

    var body: some View {
        Form {
            Section("Player") {
                TextField("Name", text: $player.name)
            }

            Section("Add Walkup Song") {
                TextField("Paste Spotify track link or URI", text: $newSongInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Start Time (m:ss)", text: $newSongStartTimeText)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("Examples: 0:15, 1:07, 2:03")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Add Song") {
                    addSong()
                }
                .disabled(
                    cleanedSongInput.isEmpty ||
                    player.songs.count >= maxSongs ||
                    parsedNewSongStartTime == nil
                )

                if parsedNewSongStartTime == nil {
                    Text("Enter a valid time like 0:15 or 1:07.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if player.songs.count >= maxSongs {
                    Text("Players can have up to \(maxSongs) walkup songs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Walkup Songs") {
                if player.songs.isEmpty {
                    Text("No songs yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(player.songs.enumerated()), id: \.offset) { index, song in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Track \(index + 1)")
                                .font(.headline)

                            if let track = trackMetadata[song.spotifyInput] {
                                Text(track.name)
                                    .font(.body)

                                Text(track.artists.map(\.name).joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else if failedSongs.contains(song.spotifyInput) {
                                Text("Could not load track details")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Loading track details...")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("Start Time")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                TextField(
                                    "m:ss",
                                    text: Binding(
                                        get: {
                                            formattedTime(song.startTimeSeconds)
                                        },
                                        set: { newValue in
                                            updateStartTime(for: song, with: newValue)
                                        }
                                    )
                                )
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            }

                            Text(song.spotifyInput)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteSongs)
                }
            }
        }
        .navigationTitle(player.name.isEmpty ? "Player" : player.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: player.songs.map(\.spotifyInput)) {
            await loadMetadataForSongs()
        }
    }

    private var cleanedSongInput: String {
        newSongInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedNewSongStartTime: Double? {
        parseTimeToSeconds(newSongStartTimeText)
    }

    private func addSong() {
        let value = cleanedSongInput
        guard !value.isEmpty else { return }
        guard player.songs.count < maxSongs else { return }
        guard SpotifyHelpers.extractTrackID(from: value) != nil else { return }
        guard let startTimeSeconds = parsedNewSongStartTime else { return }

        player.songs.append(
            WalkupSong(
                spotifyInput: value,
                startTimeSeconds: startTimeSeconds
            )
        )

        newSongInput = ""
        newSongStartTimeText = "0:00"
    }

    private func deleteSongs(at offsets: IndexSet) {
        let songsToDelete = offsets.map { player.songs[$0].spotifyInput }

        for song in songsToDelete {
            trackMetadata.removeValue(forKey: song)
            failedSongs.remove(song)
        }

        player.songs.remove(atOffsets: offsets)
    }

    private func updateStartTime(for song: WalkupSong, with input: String) {
        guard let seconds = parseTimeToSeconds(input) else { return }
        guard let currentIndex = player.songs.firstIndex(of: song) else { return }

        player.songs[currentIndex].startTimeSeconds = seconds
    }

    private func loadMetadataForSongs() async {
        guard let token = spotifyAuth.accessToken, !token.isEmpty else {
            return
        }

        for song in player.songs {
            let input = song.spotifyInput

            guard trackMetadata[input] == nil, !failedSongs.contains(input) else { continue }

            guard let trackID = SpotifyHelpers.extractTrackID(from: input) else {
                failedSongs.insert(input)
                continue
            }

            do {
                let track = try await SpotifyService.fetchTrack(
                    trackID: trackID,
                    accessToken: token
                )
                trackMetadata[input] = track
            } catch {
                failedSongs.insert(input)
                print("Failed to fetch track metadata for \(input): \(error)")
            }
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func parseTimeToSeconds(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":")

            guard parts.count == 2,
                  let minutes = Int(parts[0]),
                  let seconds = Int(parts[1]),
                  minutes >= 0,
                  seconds >= 0,
                  seconds < 60 else {
                return nil
            }

            return Double(minutes * 60 + seconds)
        } else {
            guard let seconds = Int(trimmed), seconds >= 0 else {
                return nil
            }
            return Double(seconds)
        }
    }
}
