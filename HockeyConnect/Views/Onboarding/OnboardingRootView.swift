import SwiftUI

enum OnboardingStep: Equatable {
    case landing
    case accountType            // Player vs Group — asked FIRST
    case signInOrUp
    case auth(AuthMode)
    case playerSetup
    case groupSetup
}

struct OnboardingRootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var step: OnboardingStep = .landing
    @State private var pickedAccountType: AccountType = .player

    var body: some View {
        ZStack {
            IceBackground()
            VStack(spacing: 0) {
                if step != .landing {
                    BackBar { goBack() }
                }
                Group {
                    switch step {
                    case .landing:
                        LandingView {
                            withAnimation(.spring(response: 0.5)) {
                                step = .accountType
                            }
                        }
                    case .accountType:
                        AccountTypeView { type in
                            pickedAccountType = type
                            withAnimation(.spring(response: 0.45)) {
                                step = .signInOrUp
                            }
                        }
                    case .signInOrUp:
                        SignInOrUpView { mode in
                            withAnimation(.spring(response: 0.45)) {
                                step = .auth(mode)
                            }
                        }
                    case .auth(let mode):
                        AuthView(mode: mode, onSuccess: {
                            withAnimation(.spring(response: 0.45)) {
                                step = pickedAccountType == .player ? .playerSetup : .groupSetup
                            }
                        })
                    case .playerSetup:
                        PlayerSetupView()
                    case .groupSetup:
                        GroupSetupView()
                    }
                }
            }
        }
        .onAppear { syncWithAuthState() }
        .onChange(of: authVM.hasFirebaseUser) { _, _ in syncWithAuthState() }
    }

    // If the user is already authenticated (returning user mid-onboarding,
    // or just completed sign-in) but has no Firestore profile yet, jump to
    // the account-type picker — they still need to declare player/group
    // before setting up a profile.
    private func syncWithAuthState() {
        if authVM.hasFirebaseUser && authVM.currentUser == nil {
            switch step {
            case .landing, .signInOrUp, .auth:
                withAnimation(.spring(response: 0.45)) { step = .accountType }
            default: break
            }
        }
    }

    private func goBack() {
        withAnimation(.spring(response: 0.4)) {
            switch step {
            case .landing: break
            case .accountType: step = .landing
            case .signInOrUp: step = .accountType
            case .auth: step = .signInOrUp
            case .playerSetup, .groupSetup: step = .signInOrUp
            }
        }
    }
}

struct AccountTypeView: View {
    let onSelect: (AccountType) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 20)
            VStack(spacing: 8) {
                Text("Almost there")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text("How will you use HockeyConnect?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 16) {
                AccountTypeCard(
                    icon: "person.fill",
                    title: "Player",
                    subtitle: "Find pickup games that match your skill level"
                ) { onSelect(.player) }

                AccountTypeCard(
                    icon: "person.3.fill",
                    title: "Group / Team",
                    subtitle: "Post games and fill open spots on your roster"
                ) { onSelect(.group) }
            }
            .padding(.horizontal, 24)
            Spacer()

            Text("This is saved to your account — you can change it later in Profile.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
        }
    }
}

private struct AccountTypeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(Color.iceBlue)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}
