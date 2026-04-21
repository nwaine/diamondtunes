
import SwiftUI
import SwiftData

private let clipDuration: Double = 15.0
private let breakSongCategoriesStorageKey = "DiamondTunes.breakSongCategories"

struct GameModeView: View {
    let lineup: [Player]

    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager

    @State private var currentPlayingPlayerID: PersistentIdentifier?
    @State private var currentPlayingBreakCategoryID: UUID?
    @State private var currentTrack: SpotifyTrack?
    @State private var playbackProgress: Double = 0
    @State private var playbackTask: Task<Void, Never>?
    @State private var showDeviceWarning = false
    @State private var cachedPlaybackDeviceID: String?

    @State private var selectedMode: SessionMode = .batting
    @State private var breakSongCategories: [BreakSongCategory] = Self.defaultBreakSongCategories
    @State private var editingBreakSongCategoryID: UUID?

    private static let defaultBreakSongCategories: [BreakSongCategory] = [
        BreakSongCategory(name: "Relaxed"),
        BreakSongCategory(name: "Pump-Up"),
        BreakSongCategory(name: "Funny")
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Game Mode")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(
                            selectedMode == .batting
                            ? "Tap a player to trigger walk-up music."
                            : "Play or edit your between-innings music categories."
                        )
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    }

                    Picker("Mode", selection: $selectedMode) {
                        ForEach(SessionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

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

                            Text("Couldn’t find an active Spotify phone device. Open Spotify on your phone and start playback once, then try again.")
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

            if selectedMode == .batting {
                battingSection
            } else {
                betweenInningsSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Game Mode")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadBreakSongCategories()
        }
        .onChange(of: breakSongCategories) {
            saveBreakSongCategories()
        }
        .onDisappear {
            playbackTask?.cancel()
            playbackTask = nil
        }
        .sheet(item: editingCategoryBinding) { category in
            BreakSongCategoryPickerSheet(
                category: category,
                accessToken: spotifyAuth.accessToken,
                onSelectTrack: { track in
                    addBreakSong(track, to: category)
                },
                onRemoveSong: { song in
                    removeBreakSong(song, from: category)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var battingSection: some View {
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

    private var betweenInningsSection: some View {
        Section {
            ForEach(breakSongCategories.indices, id: \.self) { index in
                let category = breakSongCategories[index]
                let isPlaying = isCurrentlyPlayingBreakCategory(category)
                let songCount = category.songs.count

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.lineupBadgeFill)

                        Image(systemName: "music.note")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.lineupBadgeText)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        if isPlaying, let currentTrack {
                            Text("Playing: \(currentTrack.name) • \(currentTrack.artistLine)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.blue)
                                .lineLimit(1)
                        } else if songCount > 0 {
                            Text("\(songCount) saved song\(songCount == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            Text("No songs assigned yet")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer(minLength: 12)

                    Button {
                        editingBreakSongCategoryID = category.id
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.controlIcon)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.white))
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.controlRingTrack, lineWidth: 4)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            if isPlaying {
                                await stopPlayback()
                            } else if !category.songs.isEmpty {
                                await playBreakSong(category)
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)

                            Circle()
                                .stroke(AppTheme.controlRingTrack, lineWidth: 4)

                            if isPlaying {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppTheme.controlIcon)
                            } else {
                                Image(systemName: category.songs.isEmpty ? "play.slash.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(category.songs.isEmpty ? AppTheme.textSecondary : AppTheme.controlIcon)
                            }
                        }
                        .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                    .disabled(category.songs.isEmpty && !isPlaying)
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
        } header: {
            Text("Between Innings")
        } footer: {
            Text("Each category can hold multiple songs. Tapping play will randomly choose one and keep it playing until you stop it.")
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var editingCategoryBinding: Binding<BreakSongCategory?> {
        Binding<BreakSongCategory?>(
            get: {
                guard let editingBreakSongCategoryID else { return nil }
                return breakSongCategories.first(where: { $0.id == editingBreakSongCategoryID })
            },
            set: { newValue in
                editingBreakSongCategoryID = newValue?.id
            }
        )
    }

    private func addBreakSong(_ track: SpotifyTrack, to category: BreakSongCategory) {
        guard let uri = track.uri,
              let index = breakSongCategories.firstIndex(where: { $0.id == category.id }) else { return }

        let newSong = BreakSong(
            trackURI: uri,
            trackName: track.name,
            artistName: track.artistLine
        )

        if !breakSongCategories[index].songs.contains(where: { $0.trackURI == uri }) {
            breakSongCategories[index].songs.append(newSong)
        }
    }

    private func removeBreakSong(_ song: BreakSong, from category: BreakSongCategory) {
        guard let index = breakSongCategories.firstIndex(where: { $0.id == category.id }) else { return }

        breakSongCategories[index].songs.removeAll(where: { $0.id == song.id })

        if let currentTrack,
           currentPlayingBreakCategoryID == category.id,
           currentTrack.uri == song.trackURI {
            Task { await stopPlayback() }
        }
    }

    private func loadBreakSongCategories() {
        guard let data = UserDefaults.standard.data(forKey: breakSongCategoriesStorageKey) else {
            breakSongCategories = Self.defaultBreakSongCategories
            return
        }

        guard let decoded = try? JSONDecoder().decode([BreakSongCategory].self, from: data) else {
            breakSongCategories = Self.defaultBreakSongCategories
            return
        }

        if decoded.isEmpty {
            breakSongCategories = Self.defaultBreakSongCategories
        } else {
            breakSongCategories = decoded
        }
    }

    private func saveBreakSongCategories() {
        guard let data = try? JSONEncoder().encode(breakSongCategories) else { return }
        UserDefaults.standard.set(data, forKey: breakSongCategoriesStorageKey)
    }

    private func isCurrentlyPlaying(_ player: Player) -> Bool {
        currentPlayingPlayerID == player.persistentModelID
    }

    private func isCurrentlyPlayingBreakCategory(_ category: BreakSongCategory) -> Bool {
        currentPlayingBreakCategoryID == category.id
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
            try await playTrackUsingCachedDeviceFallback(
                trackURI: trackURI,
                positionMS: startMS,
                accessToken: token
            )

            await MainActor.run {
                currentPlayingPlayerID = player.persistentModelID
                currentPlayingBreakCategoryID = nil
                currentTrack = track
                playbackProgress = 0
                showDeviceWarning = false
            }

            startWalkupPlaybackTimeline(accessToken: token)
        } catch {
            print("Playback failed: \(error)")
            await MainActor.run {
                showDeviceWarning = true
            }
        }
    }

    private func playBreakSong(_ category: BreakSongCategory) async {
        guard let token = spotifyAuth.accessToken else {
            print("No Spotify token")
            return
        }

        guard let selectedSong = category.songs.randomElement() else {
            print("No songs assigned to category")
            return
        }

        let trackID = selectedSong.trackURI.replacingOccurrences(of: "spotify:track:", with: "")

        playbackTask?.cancel()
        playbackTask = nil

        do {
            let track = try? await SpotifyService.fetchTrack(trackID: trackID, accessToken: token)
            try await playTrackUsingCachedDeviceFallback(
                trackURI: selectedSong.trackURI,
                positionMS: 0,
                accessToken: token
            )

            await MainActor.run {
                currentPlayingPlayerID = nil
                currentPlayingBreakCategoryID = category.id
                currentTrack = track ?? SpotifyTrack(
                    id: trackID,
                    name: selectedSong.trackName,
                    artists: [SpotifyArtist(name: selectedSong.artistName)],
                    album: nil,
                    uri: selectedSong.trackURI
                )
                playbackProgress = 0
                showDeviceWarning = false
            }
        } catch {
            print("Break song playback failed: \(error)")
            await MainActor.run {
                showDeviceWarning = true
            }
        }
    }

    private func stopPlayback() async {
        guard let token = spotifyAuth.accessToken else { return }

        playbackTask?.cancel()
        playbackTask = nil

        do {
            try await SpotifyService.pausePlayback(accessToken: token)
        } catch {
            print("Pause failed: \(error)")
        }

        await MainActor.run {
            currentPlayingPlayerID = nil
            currentPlayingBreakCategoryID = nil
            currentTrack = nil
            playbackProgress = 0
        }
    }

    private func startWalkupPlaybackTimeline(accessToken: String) {
        playbackTask?.cancel()

        playbackTask = Task {
            let updateInterval: Double = 0.05
            let totalSteps = max(Int(clipDuration / updateInterval), 1)

            for step in 0...totalSteps {
                if Task.isCancelled { return }

                let progress = min(Double(step) / Double(totalSteps), 1.0)

                await MainActor.run {
                    playbackProgress = progress
                }

                if step < totalSteps {
                    try? await Task.sleep(for: .seconds(updateInterval))
                }
            }

            do {
                try await SpotifyService.pausePlayback(accessToken: accessToken)
            } catch {
                print("Auto-stop pause failed: \(error)")
            }

            await MainActor.run {
                currentPlayingPlayerID = nil
                currentPlayingBreakCategoryID = nil
                currentTrack = nil
                playbackProgress = 0
                playbackTask = nil
            }
        }
    }

    private func playTrackUsingCachedDeviceFallback(trackURI: String, positionMS: Int, accessToken: String) async throws {
        if let cachedPlaybackDeviceID {
            do {
                try await SpotifyService.playTrack(
                    trackURI: trackURI,
                    positionMS: positionMS,
                    deviceID: cachedPlaybackDeviceID,
                    accessToken: accessToken
                )
                return
            } catch {
                print("Cached device play failed, refreshing devices...")
                await MainActor.run {
                    self.cachedPlaybackDeviceID = nil
                }
            }
        }

        let devices = try await SpotifyService.fetchAvailableDevices(accessToken: accessToken)

        guard let preferredDevice = preferredPlaybackDevice(from: devices) else {
            throw SpotifyServiceError.badResponse
        }

        try await SpotifyService.transferPlayback(
            deviceID: preferredDevice.id,
            play: false,
            accessToken: accessToken
        )

        try? await Task.sleep(for: .milliseconds(350))

        try await SpotifyService.playTrack(
            trackURI: trackURI,
            positionMS: positionMS,
            deviceID: preferredDevice.id,
            accessToken: accessToken
        )

        await MainActor.run {
            self.cachedPlaybackDeviceID = preferredDevice.id
        }
    }

    private func preferredPlaybackDevice(from devices: [SpotifyDevice]) -> SpotifyDevice? {
        devices.first(where: { $0.isActive && !$0.isRestricted })
        ?? devices.first(where: { $0.type.lowercased().contains("smartphone") && !$0.isRestricted })
        ?? devices.first(where: { $0.name.lowercased().contains("iphone") && !$0.isRestricted })
        ?? devices.first(where: { !$0.isRestricted })
    }
}

private enum SessionMode: String, CaseIterable, Identifiable {
    case batting
    case betweenInnings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .batting:
            return "Batting"
        case .betweenInnings:
            return "Between Innings"
        }
    }
}

private struct BreakSongCategoryPickerSheet: View {
    let category: BreakSongCategory
    let accessToken: String?
    let onSelectTrack: (SpotifyTrack) -> Void
    let onRemoveSong: (BreakSong) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [SpotifyTrack] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.name)
                            .font(.title3.weight(.bold))

                        Text("Search Spotify and add one or more songs for this between-innings category.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Saved Songs") {
                    if category.songs.isEmpty {
                        Text("No songs saved yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(category.songs) { song in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.trackName)
                                        .font(.headline)
                                    Text(song.artistName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    onRemoveSong(song)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }

                Section("Search Results") {
                    if isSearching {
                        HStack {
                            ProgressView()
                            Text("Searching Spotify...")
                                .foregroundStyle(.secondary)
                        }
                    } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Type a song name, artist, or both in the search bar.")
                            .foregroundStyle(.secondary)
                    } else if results.isEmpty {
                        Text("No results yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(results, id: \.id) { track in
                            Button {
                                onSelectTrack(track)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(track.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(track.artistLine)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AppTheme.blue)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit \(category.name)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Spotify")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Search") {
                        Task { await search() }
                    }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }
            }
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let accessToken, !accessToken.isEmpty else {
            errorMessage = "Spotify is not connected right now."
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            results = try await SpotifyService.searchTracks(query: trimmed, accessToken: accessToken)
        } catch {
            errorMessage = "Search failed. Try again."
            results = []
            print("Break song search failed: \(error)")
        }

        isSearching = false
    }
}
