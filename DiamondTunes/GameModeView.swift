import SwiftUI
import SwiftData

private let clipDuration: Double = 15.0

struct GameModeView: View {
    let lineup: [Player]

    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @State private var currentPlayingPlayerID: PersistentIdentifier?
    @State private var currentTrack: SpotifyTrack?
    @State private var playbackProgress: Double = 0
    @State private var playbackTask: Task<Void, Never>?
    @State private var showDeviceWarning = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Game Mode")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Tap a player to trigger walk-up music.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if let currentTrack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Now Playing")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)

                            Text(currentTrack.name)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)

                            Text(currentTrack.artistLine)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(AppTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                    }

                    if showDeviceWarning {
                        HStack(spacing: 10) {
                            Image(systemName: "iphone.slash")
                                .foregroundStyle(.orange)

                            Text("Open Spotify on your phone and start playback once to activate the device.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textPrimary)

                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            if lineup.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Text("No players in today's lineup")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Go back and choose the players who are actually at the game.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section("Lineup") {
                    ForEach(Array(lineup.enumerated()), id: \.element.persistentModelID) { index, player in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.lineupBadgeFill)

                                Text("\(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(AppTheme.lineupBadgeText)
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)

                                if isCurrentlyPlaying(player), let currentTrack {
                                    Text("\(currentTrack.name) • \(currentTrack.artistLine)")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.blue)
                                        .lineLimit(1)
                                } else {
                                    Text("\(player.songs.count) song\(player.songs.count == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }

                            Spacer()

                            Button {
                                Task {
                                    if isCurrentlyPlaying(player) {
                                        await stopPlayback()
                                    } else {
                                        await playWalkup(for: player)
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)

                                    Circle()
                                        .stroke(AppTheme.controlRingTrack, lineWidth: 4)

                                    if isCurrentlyPlaying(player) {
                                        Circle()
                                            .trim(from: 0, to: playbackProgress)
                                            .stroke(
                                                AppTheme.controlRingProgress,
                                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                            )
                                            .rotationEffect(.degrees(-90))

                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(AppTheme.controlIcon)
                                    } else {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(AppTheme.controlIcon)
                                    }
                                }
                                .frame(width: 42, height: 42)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(AppTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Game Mode")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            playbackTask?.cancel()
            playbackTask = nil
        }
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
            let track = try? await SpotifyService.fetchTrack(trackID: trackID, accessToken: token)

            try await SpotifyService.playTrack(
                trackURI: trackURI,
                positionMS: startMS,
                accessToken: token
            )

            await MainActor.run {
                currentPlayingPlayerID = player.persistentModelID
                currentTrack = track
                playbackProgress = 0
                showDeviceWarning = false
            }

            startPlaybackTimeline(accessToken: token)
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

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                let clampedElapsed = min(elapsed, clipDuration)
                let progress = clampedElapsed / clipDuration

                await MainActor.run {
                    playbackProgress = progress
                }

                if elapsed >= clipDuration {
                    do {
                        try await SpotifyService.pausePlayback(accessToken: accessToken)
                    } catch {
                        print("Auto-stop failed: \(error)")
                    }

                    await MainActor.run {
                        currentPlayingPlayerID = nil
                        currentTrack = nil
                        playbackProgress = 0
                    }

                    playbackTask = nil
                    return
                }

                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopPlayback() async {
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
            currentTrack = nil
            playbackProgress = 0
        }
    }
}
