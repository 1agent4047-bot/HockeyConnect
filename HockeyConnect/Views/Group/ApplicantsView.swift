import SwiftUI

struct ApplicantsView: View {
    let game: Game
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = GroupDashboardViewModel()
    @State private var selectedPlayer: (AppUser, PlayerProfile)?
    @State private var showConfirm = false

    var body: some View {
        ZStack {
            IceBackground()
            Group {
                if vm.applicants.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.iceBlue.opacity(0.5))
                        Text("No applicants yet")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Text("Players matching skill level \(game.skillLevelRequired)\ncan apply to this game.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.applicants, id: \.0.id) { user, profile in
                                ApplicantCard(user: user, profile: profile, game: game) {
                                    selectedPlayer = (user, profile)
                                    showConfirm = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .navigationTitle("Applicants (\(vm.applicants.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await vm.loadApplicants(for: game) }
        .overlay {
            if case .processing = vm.paymentState { SelectPaymentOverlay() }
        }
        .confirmationDialog(
            "Select \(selectedPlayer?.0.displayName ?? "player") for $5?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Pay $5 & Select Player") {
                guard let (user, _) = selectedPlayer,
                      let playerId = user.id,
                      let groupId = authVM.currentUser?.id else { return }
                Task { await vm.selectPlayer(game: game, playerId: playerId, groupId: groupId) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Player Selected!", isPresented: .constant({
            if case .success = vm.paymentState { return true }
            return false
        }())) {
            Button("Done") { vm.paymentState = .idle }
        } message: {
            Text("The player has been notified.")
        }
    }
}

private struct ApplicantCard: View {
    let user: AppUser
    let profile: PlayerProfile
    let game: Game
    let onSelect: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle().fill(Color.iceBlue.opacity(0.2)).frame(width: 48, height: 48)
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.title3.bold())
                        .foregroundStyle(Color.iceBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        SkillBadge(level: profile.skillLevel)
                        Text("Age \(profile.age)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    let matchCount = availabilityMatches(profile.availability, gameDate: game.date)
                    if matchCount > 0 {
                        Label("Available this time", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Button(action: onSelect) {
                    Text("Select")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.iceBlue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
    }

    private func availabilityMatches(_ slots: [AvailabilitySlot], gameDate: Date) -> Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: gameDate)
        let hour = cal.component(.hour, from: gameDate)
        return slots.filter { $0.dayOfWeek == weekday && hour >= $0.startHour && hour < $0.endHour }.count
    }
}

private struct SelectPaymentOverlay: View {
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
