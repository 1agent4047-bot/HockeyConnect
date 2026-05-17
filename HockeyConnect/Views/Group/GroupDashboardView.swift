import SwiftUI

struct GroupDashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = GroupDashboardViewModel()
    @State private var showPostGame = false

    var body: some View {
        NavigationStack {
            ZStack {
                IceBackground()
                Group {
                    if vm.games.isEmpty {
                        EmptyDashboard(onPost: { showPostGame = true })
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(vm.games) { game in
                                    NavigationLink(destination: ApplicantsView(game: game)) {
                                        GroupGameCard(game: game)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle(authVM.groupProfile?.groupName ?? "Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showPostGame = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.iceBlue)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showPostGame) {
                PostGameView()
                    .environmentObject(authVM)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            if let uid = authVM.currentUser?.id {
                vm.startListening(groupId: uid)
            }
        }
        .onDisappear { vm.stopListening() }
    }
}

private struct GroupGameCard: View {
    let game: Game

    private var statusColor: Color {
        switch game.status {
        case .open: return Color.iceBlue
        case .filled: return .green
        case .cancelled: return .red
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.rinkName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(game.formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    SkillBadge(level: game.skillLevelRequired)
                }
                Divider().overlay(Color.black.opacity(0.1))
                HStack {
                    Label("\(game.applicantIds.count) applicants", systemImage: "person.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(game.status.rawValue.capitalized)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15), in: Capsule())
                }
            }
            .padding(16)
        }
    }
}

private struct EmptyDashboard: View {
    let onPost: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(Color.iceBlue.opacity(0.5))
            Text("No games posted yet")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text("Post an open game to start\nfinding players.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: onPost) {
                Label("Post a Game", systemImage: "plus")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.iceBlue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }
}
