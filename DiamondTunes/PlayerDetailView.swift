import SwiftUI
import SwiftData

struct PlayerDetailView: View {
    @Bindable var player: Player
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager

    @State private var newSongInput = ""
    @State private var newSongStartTimeText = "0:00"
    @State private var trackMetadata: [String: SpotifyTrack] = [:]
    @State private var failedSongs: Set<String> = []
    @State private var searchText = ""
    @State private var searchResults: [SpotifyTrack] = []
    @State private var isSearching = false
    @State private var searchError: String?

    private let maxSongs = 3

    var body: some View {
        Form {
            Section("Player") {
                TextField("Name", text: $player.name)
            }

            Section("Find Walkup Song") {
                if spotifyAuth.isConnected {
                    TextField("Search Spotify", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Search") {
                        Task {
                            await runTrackSearch()
                        }
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || player.songs.count >= maxSongs)

                    if isSearching {
                        ProgressView("Searching Spotify...")
                    }

                    if let searchError {
                        Text(searchError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if !searchResults.isEmpty {
                        ForEach(searchResults, id: \.id) { track in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(track.name)
                                    .font(.headline)

                                Text(track.artistLine)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack {
                                    TextField("Start Time (m:ss)", text: $newSongStartTimeText)
                                        .keyboardType(.numbersAndPunctuation)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()

                                    Button("Use This Song") {
                                        addSong(from: track)
                                    }
                                    .disabled(parsedNewSongStartTime == nil || player.songs.count >= maxSongs)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Text("Connect Spotify on the main screen to search and save songs from inside the app.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Add Walkup Song Manually") {
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
                    addSongManually()
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

                                Text(track.artistLine)
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

    private func addSongManually() {
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

    private func addSong(from track: SpotifyTrack) {
        guard player.songs.count < maxSongs else { return }
        guard let startTimeSeconds = parsedNewSongStartTime else { return }

        let spotifyInput = "spotify:track:\(track.id)"
        player.songs.append(
            WalkupSong(
                spotifyInput: spotifyInput,
                startTimeSeconds: startTimeSeconds
            )
        )
        trackMetadata[spotifyInput] = track
        searchText = ""
        searchResults = []
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

    private func runTrackSearch() async {
        guard let token = spotifyAuth.accessToken, !token.isEmpty else {
            searchError = "Connect Spotify first."
            return
        }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        searchError = nil

        do {
            searchResults = try await SpotifyService.searchTracks(query: trimmed, accessToken: token)
            if searchResults.isEmpty {
                searchError = "No matching tracks found."
            }
        } catch {
            searchResults = []
            searchError = "Spotify search failed."
            print("Spotify search failed: \(error)")
        }

        isSearching = false
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
