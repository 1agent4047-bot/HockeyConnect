import SwiftUI

struct PostGameView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = GroupDashboardViewModel()
    @State private var date = Date().addingTimeInterval(86400)
    @State private var rinkName = ""
    @State private var skillLevel = 3
    @State private var forwardSpots = 2
    @State private var defenseSpots = 1
    @State private var goalieSpots = 0
    @State private var isPosting = false

    private var totalSpots: Int { forwardSpots + defenseSpots + goalieSpots }
    private var isValid: Bool { !rinkName.isEmpty && totalSpots > 0 }

    var body: some View {
        ZStack {
            IceBackground()
            ScrollView {
                VStack(spacing: 24) {
                    Text("Post a Game")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .padding(.top, 20)

                    GlassCard {
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date & Time")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                DatePicker("", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .colorScheme(.dark)
                                    .labelsHidden()
                            }

                            FormField(label: "Rink Name", text: $rinkName, placeholder: "AZ Ice Peoria")

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Skill Level Required")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                SkillSelector(selected: $skillLevel)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Open Spots by Position")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Stepper("Forwards: \(forwardSpots)", value: $forwardSpots, in: 0...20)
                                    .foregroundStyle(.primary)

                                Stepper("Defense: \(defenseSpots)", value: $defenseSpots, in: 0...20)
                                    .foregroundStyle(.primary)

                                Stepper("Goalies: \(goalieSpots)", value: $goalieSpots, in: 0...2)
                                    .foregroundStyle(.primary)

                                Text("Total open: \(totalSpots)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(totalSpots == 0 ? .red : Color.iceBlue)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(20)
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        Button("Cancel") { dismiss() }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.15), lineWidth: 1))
                            .foregroundStyle(.secondary)

                        Button(action: post) {
                            Group {
                                if isPosting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Post Game").fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isValid ? Color.iceBlue : Color.iceBlue.opacity(0.4))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isValid || isPosting)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func post() {
        guard let uid = authVM.currentUser?.id,
              let groupName = authVM.groupProfile?.groupName else { return }
        isPosting = true
        Task {
            await vm.postGame(
                groupId: uid,
                groupName: groupName,
                rinkName: rinkName.isEmpty ? (authVM.groupProfile?.rinkName ?? "") : rinkName,
                date: date,
                skillLevel: skillLevel,
                forwardSpots: forwardSpots,
                defenseSpots: defenseSpots,
                goalieSpots: goalieSpots
            )
            isPosting = false
            dismiss()
        }
    }
}
