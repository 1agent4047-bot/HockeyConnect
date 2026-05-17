import SwiftUI

struct GameDetailView: View {
    let game: Game
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = PlayerFeedViewModel()
    @State private var showConfirm = false

    var body: some View {
        ZStack {
            IceBackground()
            ScrollView {
                VStack(spacing: 20) {
                    // Header card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(game.groupName)
                                        .font(.title2.bold())
                                        .foregroundStyle(.primary)
                                    Text(game.rinkName)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                SkillBadge(level: game.skillLevelRequired)
                            }
                            Divider().overlay(Color.black.opacity(0.1))

                            DetailRow(icon: "calendar", label: "Date & Time", value: game.formattedDate)
                            DetailRow(icon: "mappin.circle.fill", label: "Rink", value: game.rinkName)
                            DetailRow(icon: "person.2.fill", label: "Spots Available", value: "\(game.spotsAvailable) of \(game.spotsTotal)")
                        }
                        .padding(20)
                    }

                    // $5 referral info
                    GlassCard {
                        HStack(spacing: 14) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.iceBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("$5 referral fee")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("One-time fee to join this game via HockeyConnect")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                    }

                    // Join button
                    Button {
                        showConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Join Game — $5")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(game.isFull ? Color.gray.opacity(0.4) : Color.iceBlue)
                        .foregroundStyle(game.isFull ? .white.opacity(0.5) : .black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(game.isFull)
                }
                .padding(16)
            }
        }
        .navigationTitle("Game Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("Join this game for $5?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Pay $5 & Join") {
                Task {
                    guard let uid = authVM.currentUser?.id else { return }
                    await vm.joinGame(game, playerId: uid)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay {
            if case .processing = vm.paymentState { PaymentOverlay() }
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.iceBlue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }
}

private struct PaymentOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            GlassCard {
                VStack(spacing: 16) {
                    ProgressView().tint(Color.iceBlue).scaleEffect(1.4)
                    Text("Processing...").foregroundStyle(.primary)
                }
                .padding(32)
            }
            .padding(40)
        }
    }
}
