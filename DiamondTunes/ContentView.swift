import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Player.battingOrder) private var players: [Player]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager

    @State private var playerToDelete: Player?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DiamondTunes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Walk-Up Manager")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, 4)
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spotify")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.textPrimary)

                        if spotifyAuth.isConnected {
                            Label("Connected to Spotify", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                                .font(.subheadline.weight(.semibold))

                            if let connectedText = spotifyAuth.connectionStatusText {
                                Text(connectedText)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
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
                                .padding(.vertical, 14)
                                .background(AppTheme.red)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)

                            if spotifyAuth.isAuthenticating {
                                Text("Waiting for Spotify login...")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            } else {
                                Text("Once you connect once, the app will restore your Spotify session automatically on future launches.")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                Section {
                    NavigationLink {
                        TodayLineupView()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "list.number")
                            Text("Set Today's Lineup")
                                .fontWeight(.semibold)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.bold))
                                .opacity(0.8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(AppTheme.gameButtonFill)
                        .foregroundStyle(AppTheme.gameButtonText)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }

                Section {
                    if players.isEmpty {
                        VStack(spacing: 12) {
                            Text("No players yet")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Add your first player to start building your lineup.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(players) { player in
                            NavigationLink {
                                PlayerDetailView(player: player)
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(player.name)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.textPrimary)

                                        Text("\(player.songs.count) song\(player.songs.count == 1 ? "" : "s")")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }

                                    Spacer()

                                    Text("#\(player.battingOrder + 1)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(AppTheme.rowFill)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    playerToDelete = player
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(AppTheme.red)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Roster")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Button {
                            addPlayer()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.navy)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                normalizeBattingOrderIfNeeded()
                spotifyAuth.restoreSessionIfPossible()
            }
            .alert(
                "Remove Player?",
                isPresented: Binding(
                    get: { playerToDelete != nil },
                    set: { if !$0 { playerToDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let player = playerToDelete {
                        deletePlayer(player)
                    }
                    playerToDelete = nil
                }

                Button("Cancel", role: .cancel) {
                    playerToDelete = nil
                }
            } message: {
                Text("This will remove the player from your roster.")
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
        try? context.save()
    }

    private func deletePlayer(_ player: Player) {
        context.delete(player)
        try? context.save()
        normalizeBattingOrderIfNeeded()
    }

    private func normalizeBattingOrderIfNeeded() {
        for (index, player) in players.enumerated() where player.battingOrder != index {
            player.battingOrder = index
        }
        try? context.save()
    }
}
