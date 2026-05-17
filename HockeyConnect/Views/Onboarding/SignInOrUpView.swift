import SwiftUI

enum AuthMode: Equatable {
    case signIn
    case signUp
}

struct SignInOrUpView: View {
    let onSelect: (AuthMode) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 40)

            VStack(spacing: 10) {
                Image(systemName: "hockey.puck.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.iceBlue)
                Text("Welcome")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text("Let's get you on the ice.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 14) {
                ChoiceButton(
                    title: "I have an account",
                    subtitle: "Sign in",
                    icon: "person.fill.checkmark",
                    isPrimary: true
                ) { onSelect(.signIn) }

                ChoiceButton(
                    title: "I'm new here",
                    subtitle: "Create an account",
                    icon: "person.fill.badge.plus",
                    isPrimary: false
                ) { onSelect(.signUp) }
            }
            .padding(.horizontal, 24)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                Text("Encrypted end-to-end · Passwords never stored in plaintext")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }
}

private struct ChoiceButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isPrimary ? .white : Color.iceBlue)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isPrimary ? .white : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isPrimary ? .white.opacity(0.85) : .secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(isPrimary ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [Color.iceBlue, Color(red: 0.13, green: 0.42, blue: 0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.white
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPrimary ? Color.clear : Color.black.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isPrimary ? 0.15 : 0.04), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
