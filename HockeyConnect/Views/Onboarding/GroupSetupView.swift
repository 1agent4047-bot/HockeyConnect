import SwiftUI

// MARK: - Group Setup Flow
//
// Mirrors the player setup pattern but with group-specific fields:
//   .contact (name)  →  .phone (+ 6-digit code)  →  .details (group name / rink)
//
// The phone code step is the shared PhoneVerifyStep so the UX is identical
// across player and group signups.

enum GroupSetupStep: Equatable {
    case contact
    case phone
    case details
}

struct GroupSetupView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var step: GroupSetupStep = .contact
    @State private var displayName = ""
    @State private var phone = ""
    @State private var groupName = ""
    @State private var rinkName = ""
    @State private var rinkAddress = ""
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Group {
                switch step {
                case .contact:
                    GroupContactStep(
                        displayName: $displayName,
                        onNext: { withAnimation(.spring(response: 0.45)) { step = .phone } }
                    )
                case .phone:
                    PhoneVerifyStep(
                        phone: $phone,
                        stepNumber: 2,
                        totalSteps: 3,
                        onBack: { withAnimation(.spring(response: 0.45)) { step = .contact } },
                        onVerified: { withAnimation(.spring(response: 0.45)) { step = .details } }
                    )
                case .details:
                    GroupDetailsStep(
                        groupName: $groupName,
                        rinkName: $rinkName,
                        rinkAddress: $rinkAddress,
                        isSaving: isSaving,
                        onBack: { withAnimation(.spring(response: 0.45)) { step = .phone } },
                        onFinish: { save() }
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            if let err = authVM.errorMessage {
                VStack {
                    Spacer()
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.92), in: Capsule())
                        .padding(.bottom, 28)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.4), value: authVM.errorMessage)
    }

    private func save() {
        isSaving = true
        Task {
            await authVM.finishGroupSetup(
                displayName: displayName,
                phone: phone,
                groupName: groupName,
                rinkName: rinkName,
                rinkAddress: rinkAddress
            )
            isSaving = false
        }
    }
}

// MARK: - Step 1: Contact name

private struct GroupContactStep: View {
    @Binding var displayName: String
    let onNext: () -> Void

    private var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                StepHeader(
                    step: 1, total: 3,
                    title: "Contact Info",
                    subtitle: "Who runs this group? Players will see this name."
                )

                GlassCard {
                    FormField(label: "Contact Name", text: $displayName, placeholder: "Mike Johnson")
                        .padding(24)
                }
                .padding(.horizontal, 24)

                PrimaryButton(title: "Continue", enabled: canContinue, action: onNext)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 30)
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Step 3: Group / rink details

private struct GroupDetailsStep: View {
    @Binding var groupName: String
    @Binding var rinkName: String
    @Binding var rinkAddress: String
    let isSaving: Bool
    let onBack: () -> Void
    let onFinish: () -> Void

    private var canFinish: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !rinkName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSaving
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StepHeader(
                    step: 3, total: 3,
                    title: "Group Details",
                    subtitle: "Tell players where you skate"
                )

                GlassCard {
                    VStack(spacing: 20) {
                        FormField(label: "Group / Team Name", text: $groupName, placeholder: "Desert Hawks")
                        FormField(label: "Home Rink", text: $rinkName, placeholder: "AZ Ice Peoria")
                        FormField(label: "Rink Address", text: $rinkAddress, placeholder: "9260 W Peoria Ave, Peoria AZ")
                    }
                    .padding(24)
                }
                .padding(.horizontal, 24)

                PrimaryButton(
                    title: isSaving ? "Saving…" : "Create Group",
                    enabled: canFinish,
                    action: onFinish
                )
                .padding(.horizontal, 24)

                BackTextButton(title: "Back", action: onBack)

                Spacer().frame(height: 30)
            }
            .padding(.top, 16)
        }
    }
}
