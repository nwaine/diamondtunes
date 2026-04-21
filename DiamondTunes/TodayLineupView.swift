import SwiftUI
import SwiftData

struct TodayLineupView: View {
    @Query(sort: \Player.battingOrder) private var players: [Player]
    @State private var lineup: [Player] = []

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Lineup")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Choose which roster players are active today, then drag to set batting order.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            if players.isEmpty {
                Section {
                    Text("Add players to your roster first.")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                Section("Available Players") {
                    ForEach(players) { player in
                        Button {
                            toggle(player)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected(player) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected(player) ? AppTheme.success : AppTheme.textSecondary)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.name)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)

                                    Text("\(player.songs.count) song\(player.songs.count == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }

                                Spacer()

                                if isSelected(player), let index = lineup.firstIndex(where: { $0.persistentModelID == player.persistentModelID }) {
                                    Text("#\(index + 1)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.blue)
                                }
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
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }

                if !lineup.isEmpty {
                    Section("Selected Lineup") {
                        ForEach(Array(lineup.enumerated()), id: \.element.persistentModelID) { index, player in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.lineupBadgeFill)

                                    Text("\(index + 1)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(AppTheme.lineupBadgeText)
                                }
                                .frame(width: 36, height: 36)

                                Text(player.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)

                                Spacer()

                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(AppTheme.textSecondary)
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
                        .onMove(perform: moveSelectedPlayers)
                    }

                    Section {
                        NavigationLink {
                            GameModeView(lineup: lineup)
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Game Mode")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(lineup.count)")
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.surface.opacity(0.18))
                                    .clipShape(Capsule())
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
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !lineup.isEmpty {
                EditButton()
            }
        }
        .onAppear {
            if lineup.isEmpty {
                lineup = players
            } else {
                syncLineupWithRoster()
            }
        }
    }

    private func isSelected(_ player: Player) -> Bool {
        lineup.contains(where: { $0.persistentModelID == player.persistentModelID })
    }

    private func toggle(_ player: Player) {
        if let index = lineup.firstIndex(where: { $0.persistentModelID == player.persistentModelID }) {
            lineup.remove(at: index)
        } else {
            lineup.append(player)
        }
    }

    private func moveSelectedPlayers(from source: IndexSet, to destination: Int) {
        lineup.move(fromOffsets: source, toOffset: destination)
    }

    private func syncLineupWithRoster() {
        let validIDs = Set(players.map(\.persistentModelID))
        lineup = lineup.filter { validIDs.contains($0.persistentModelID) }

        for player in players where !isSelected(player) {
            continue
        }
    }
}
