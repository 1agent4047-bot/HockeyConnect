import SwiftUI

struct GamesFeedView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = PlayerFeedViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                IceBackground()
                Group {
                    if vm.games.isEmpty {
                        EmptyFeedView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(vm.games) { game in
                                    NavigationLink(destination: GameDetailView(game: game)) {
                                        GameCard(game: game)
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
            .navigationTitle("Open Games")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            if let profile = authVM.playerProfile {
                vm.startListening(
                    skillLevel: profile.skillLevel,
                    eligiblePositions: profile.eligiblePositions
                )
            }
        }
        .onDisappear { vm.stopListening() }
        .overlay {
            if case .processing = vm.paymentState { PaymentLoadingOverlay() }
        }
        .alert("Game Joined!", isPresented: .constant({
            if case .success = vm.paymentState { return true }
            return false
        }())) {
            Button("OK") { vm.paymentState = .idle }
        } message: {
            Text("You're in! The group will be notified.")
        }
    }
}

private struct GameCard: View {
    let game: Game

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.groupName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(game.rinkName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    SkillBadge(level: game.skillLevelRequired)
                }
                Divider().overlay(Color.black.opacity(0.1))
                HStack {
                    Label(game.formattedDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("\(game.spotsAvailable) spots left", systemImage: "person.badge.plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(game.spotsAvailable <= 2 ? .orange : Color.iceBlue)
                }

                if game.forwardSpots + game.defenseSpots + game.goalieSpots > 0 {
                    HStack(spacing: 8) {
                        if game.forwardSpots > 0 {
                            PositionChip(label: "\(game.forwardSpots) F", color: Color(red: 0.94, green: 0.51, blue: 0.20))
                        }
                        if game.defenseSpots > 0 {
                            PositionChip(label: "\(game.defenseSpots) D", color: Color(red: 0.20, green: 0.55, blue: 0.78))
                        }
                        if game.goalieSpots > 0 {
                            PositionChip(label: "\(game.goalieSpots) G", color: Color(red: 0.46, green: 0.36, blue: 0.78))
                        }
                        Spacer()
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct PositionChip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

private struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt")
                .font(.system(size: 60))
                .foregroundStyle(Color.iceBlue.opacity(0.5))
            Text("No games right now")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text("Check back soon — groups post\nnew games every week.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PaymentLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            GlassCard {
                VStack(spacing: 16) {
                    ProgressView().tint(Color.iceBlue).scaleEffect(1.4)
                    Text("Processing payment...")
                        .foregroundStyle(.primary)
                }
                .padding(32)
            }
            .padding(40)
        }
    }
}
