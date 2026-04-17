//
//  GameModeView.swift
//  DiamondTunes
//
//  Created by Nick Waine on 4/15/26.
//

import SwiftUI
import SwiftData

private let clipDuration: Double = 15.0
private let fadeDuration: Double = 3.0
private let assumedNormalVolume = 100

struct GameModeView: View {
    @Query(sort: \Player.battingOrder) private var players: [Player]
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager

    @State private var currentPlayingPlayerID: PersistentIdentifier?
    @State private var playbackProgress: Double = 0
    @State private var playbackTask: Task<Void, Never>?
    @State private var showDeviceWarning = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Game Mode")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(
                            editMode?.wrappedValue.isEditing == true
                            ? "Drag players into batting order."
                            : "Tap a player to trigger walk-up music."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    if showDeviceWarning {
                        HStack(spacing: 10) {
                            Image(systemName: "iphone.slash")
                                .foregroundStyle(.orange)

                            Text("Open Spotify on your phone and start playback once to activate the device.")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
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
                                    Task {
                                        if isCurrentlyPlaying(player) {
                                            await stopPlaybackWithFade()
                                        } else {
                                            await playWalkup(for: player)
                                        }
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                                            .frame(width: 40, height: 40)

                                        if isCurrentlyPlaying(player) {
                                            Circle()
                                                .trim(from: 0, to: playbackProgress)
                                                .stroke(
                                                    Color.green,
                                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                                )
                                                .rotationEffect(.degrees(-90))
                                                .frame(width: 40, height: 40)

                                            Image(systemName: "stop.fill")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.primary)
                                        } else {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.primary)
                                        }
                                    }
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
        .onDisappear {
            playbackTask?.cancel()
            playbackTask = nil
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

    private func isCurrentlyPlaying(_ player: Player) -> Bool {
        currentPlayingPlayerID == player.persistentModelID
    }

    private func playWalkup(for player: Player) async {
        guard let token = spotifyAuth.accessToken else {
            print("No Spotify token")
            return
        }

        guard !player.songs.isEmpty else {
            print("No songs for player")
            return
        }

        let selected = player.songs.randomElement()!

        guard let trackID = SpotifyHelpers.extractTrackID(from: selected.spotifyInput) else {
            print("Invalid track")
            return
        }

        let trackURI = "spotify:track:\(trackID)"
        let startMS = Int(selected.startTimeSeconds * 1000)

        playbackTask?.cancel()
        playbackTask = nil

        do {
            try await SpotifyService.playTrack(
                trackURI: trackURI,
                positionMS: startMS,
                accessToken: token
            )

            await MainActor.run {
                currentPlayingPlayerID = player.persistentModelID
                playbackProgress = 0
                showDeviceWarning = false
            }

            startPlaybackTimeline(accessToken: token)

            print("Playing \(trackURI) from \(selected.startTimeSeconds)s")
        } catch {
            print("Playback failed: \(error)")

            await MainActor.run {
                showDeviceWarning = true
            }
        }
    }

    private func startPlaybackTimeline(accessToken: String) {
        playbackTask?.cancel()

        playbackTask = Task {
            let startedAt = Date()
            let fadeStartTime = max(clipDuration - fadeDuration, 0)
            var lastVolumeSent = assumedNormalVolume
            var volumeControlAvailable = true

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                let clampedElapsed = min(elapsed, clipDuration)
                let progress = clampedElapsed / clipDuration

                await MainActor.run {
                    playbackProgress = progress
                }

                if volumeControlAvailable && elapsed >= fadeStartTime {
                    let fadeElapsed = min(elapsed - fadeStartTime, fadeDuration)
                    let fadeFraction = fadeDuration > 0 ? pow(fadeElapsed / fadeDuration, 1.5) : 1.0
                    let targetVolume = Int(Double(assumedNormalVolume) * (1.0 - fadeFraction))

                    if targetVolume != lastVolumeSent {
                        do {
                            try await SpotifyService.setPlaybackVolume(
                                volumePercent: max(0, targetVolume),
                                accessToken: accessToken
                            )
                            lastVolumeSent = targetVolume
                        } catch {
                            print("Volume fading unavailable on this device: \(error)")
                            volumeControlAvailable = false
                        }
                    }
                }

                if elapsed >= clipDuration {
                    do {
                        try await SpotifyService.pausePlayback(accessToken: accessToken)
                    } catch {
                        print("Auto-stop failed: \(error)")
                    }

                    if volumeControlAvailable {
                        do {
                            try await SpotifyService.setPlaybackVolume(
                                volumePercent: assumedNormalVolume,
                                accessToken: accessToken
                            )
                        } catch {
                            print("Volume reset failed: \(error)")
                        }
                    }

                    await MainActor.run {
                        currentPlayingPlayerID = nil
                        playbackProgress = 0
                    }

                    playbackTask = nil
                    return
                }

                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopPlaybackWithFade() async {
        guard let token = spotifyAuth.accessToken else {
            print("No Spotify token")
            return
        }

        playbackTask?.cancel()
        playbackTask = nil

        do {
            try await SpotifyService.pausePlayback(accessToken: token)
        } catch {
            print("Stop failed: \(error)")
        }

        await MainActor.run {
            currentPlayingPlayerID = nil
            playbackProgress = 0
        }
    }
}
