import SwiftUI

// MARK: - Player Setup Flow
//
// Multi-step onboarding for players:
//   .nameAge → (minor disclaimer overlay if 12-17) → .phone → .skill → done
//
// State for the in-progress profile lives in this container view and is only
// persisted to Firestore when the final "Finish" tap on the skill step fires.

enum PlayerSetupStep: Equatable {
    case nameAge
    case phone
    case position
    case skill
}

struct PlayerSetupView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var step: PlayerSetupStep = .nameAge
    @State private var displayName = ""
    @State private var age = 25
    @State private var phone = ""
    @State private var position: Position = .forward
    @State private var playsBothWays = false
    @State private var skillLevel = 3
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Group {
                switch step {
                case .nameAge:
                    NameAgeStep(
                        displayName: $displayName,
                        age: $age,
                        onNext: { withAnimation(.spring(response: 0.45)) { step = .phone } }
                    )
                case .phone:
                    PhoneVerifyStep(
                        phone: $phone,
                        stepNumber: 2,
                        totalSteps: 4,
                        onBack: { withAnimation(.spring(response: 0.45)) { step = .nameAge } },
                        onVerified: { withAnimation(.spring(response: 0.45)) { step = .position } }
                    )
                case .position:
                    PositionStep(
                        position: $position,
                        playsBothWays: $playsBothWays,
                        onBack: { withAnimation(.spring(response: 0.45)) { step = .phone } },
                        onNext: { withAnimation(.spring(response: 0.45)) { step = .skill } }
                    )
                case .skill:
                    SkillLevelStep(
                        skillLevel: $skillLevel,
                        stepNumber: 4,
                        totalSteps: 4,
                        isSaving: isSaving,
                        onBack: { withAnimation(.spring(response: 0.45)) { step = .position } },
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
            await authVM.finishPlayerSetup(
                displayName: displayName,
                phone: phone,
                skillLevel: skillLevel,
                age: age,
                position: position,
                playsBothWays: playsBothWays
            )
            isSaving = false
        }
    }
}

// MARK: - Step 3: Position (forward / defense / goalie + flexibility)

private struct PositionStep: View {
    @Binding var position: Position
    @Binding var playsBothWays: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StepHeader(
                    step: 3, total: 4,
                    title: "Your Position",
                    subtitle: "Used to match you with games that need someone like you"
                )

                VStack(spacing: 12) {
                    PositionCard(
                        position: .forward,
                        isSelected: position == .forward,
                        onTap: { withAnimation(.spring(response: 0.3)) { position = .forward } }
                    )
                    PositionCard(
                        position: .defense,
                        isSelected: position == .defense,
                        onTap: { withAnimation(.spring(response: 0.3)) { position = .defense } }
                    )
                    PositionCard(
                        position: .goalie,
                        isSelected: position == .goalie,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                position = .goalie
                                playsBothWays = false
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)

                if position != .goalie {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $playsBothWays) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("I can also play \(position == .forward ? "defense" : "forward")")
                                        .font(.subheadline.weight(.semibold))
                                    Text(playsBothWays
                                         ? "You'll see games needing a \(position == .forward ? "D" : "forward") too."
                                         : "Only \(position.label.lowercased()) games will show up.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color.iceBlue))
                        }
                        .padding(20)
                    }
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                }

                PrimaryButton(title: "Continue", enabled: true, action: onNext)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                BackTextButton(title: "Back", action: onBack)

                Spacer().frame(height: 30)
            }
            .padding(.top, 16)
            .animation(.spring(response: 0.35), value: position)
        }
    }
}

private struct PositionCard: View {
    let position: Position
    let isSelected: Bool
    let onTap: () -> Void

    private var iconName: String {
        switch position {
        case .forward: return "figure.skating"
        case .defense: return "shield.fill"
        case .goalie:  return "hand.raised.fill"
        }
    }

    private var blurb: String {
        switch position {
        case .forward: return "Score goals, drive the play"
        case .defense: return "Lock it down, move the puck"
        case .goalie:  return "Stop pucks. Stand on your head."
        }
    }

    private var color: Color {
        switch position {
        case .forward: return Color(red: 0.94, green: 0.51, blue: 0.20)
        case .defense: return Color(red: 0.20, green: 0.55, blue: 0.78)
        case .goalie:  return Color(red: 0.46, green: 0.36, blue: 0.78)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isSelected ? 1.0 : 0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(position.label)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.black.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 1: Name + Age (+ minor disclaimer)

private struct NameAgeStep: View {
    @Binding var displayName: String
    @Binding var age: Int
    let onNext: () -> Void

    @State private var showMinorDisclaimer = false
    @State private var acknowledgedMinor = false

    private var isMinor: Bool { age >= 12 && age <= 17 }
    private var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (!isMinor || acknowledgedMinor)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                StepHeader(step: 1, total: 3, title: "Your Name & Age", subtitle: "We need a few basics to set up your profile")

                GlassCard {
                    VStack(spacing: 20) {
                        FormField(label: "Full Name", text: $displayName, placeholder: "John Smith")

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Age")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Stepper("\(age) years old", value: $age, in: 12...80)
                                .foregroundStyle(.primary)
                                .onChange(of: age) { _, newValue in
                                    if newValue >= 12 && newValue <= 17 {
                                        showMinorDisclaimer = true
                                    } else {
                                        acknowledgedMinor = false
                                    }
                                }
                        }

                        if isMinor {
                            MinorDisclaimerInline(acknowledged: $acknowledgedMinor)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(24)
                }
                .padding(.horizontal, 24)

                PrimaryButton(title: "Continue", enabled: canContinue, action: onNext)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 30)
            }
            .padding(.top, 16)
            .animation(.spring(response: 0.35), value: isMinor)
        }
        .alert("Heads up", isPresented: $showMinorDisclaimer) {
            Button("I understand") { acknowledgedMinor = true }
            Button("Change age", role: .cancel) {}
        } message: {
            Text("Players under 18 may not be allowed to join some adult groups. Group organizers see your age before approving you.")
        }
    }
}

private struct MinorDisclaimerInline: View {
    @Binding var acknowledged: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Disclaimer")
                    .font(.subheadline.weight(.semibold))
                Text("Minors might not be able to play in some groups.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("I understand", isOn: $acknowledged)
                    .toggleStyle(SwitchToggleStyle(tint: Color.iceBlue))
                    .font(.caption.weight(.medium))
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Step 2: Phone + 6-digit code verification

struct PhoneVerifyStep: View {
    @Binding var phone: String
    var stepNumber: Int = 2
    var totalSteps: Int = 3
    let onBack: () -> Void
    let onVerified: () -> Void

    @State private var enteredCode = ""
    @State private var codeSent = false
    @State private var codeError: String?
    @State private var isSending = false
    @State private var isVerifying = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepHeader

                if !codeSent {
                    enterPhoneCard
                } else {
                    enterCodeCard
                }

                Spacer().frame(height: 30)
            }
            .padding(.top, 16)
        }
    }

    private var stepHeader: some View {
        StepHeader(
            step: stepNumber, total: totalSteps,
            title: codeSent ? "Enter the Code" : "Verify Your Phone",
            subtitle: codeSent
                ? "Sent to \(phone)"
                : "We'll text you a 6-digit code"
        )
    }

    private var enterPhoneCard: some View {
        VStack(spacing: 20) {
            GlassCard {
                FormField(
                    label: "Phone Number",
                    text: $phone,
                    placeholder: "+1 (480) 555-0100",
                    keyboard: .phonePad
                )
                .padding(24)
            }
            .padding(.horizontal, 24)

            PrimaryButton(
                title: isSending ? "Sending…" : "Send Code",
                enabled: phone.count >= 7 && !isSending,
                action: sendCode
            )
            .padding(.horizontal, 24)

            BackTextButton(title: "Back", action: onBack)
        }
    }

    private var enterCodeCard: some View {
        VStack(spacing: 20) {
            GlassCard {
                VStack(spacing: 14) {
                    Text("6-Digit Code")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("000000", text: $enteredCode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .tracking(8)
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: enteredCode) { _, newValue in
                            enteredCode = String(newValue.filter(\.isNumber).prefix(6))
                            codeError = nil
                        }

                    if let err = codeError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(24)
            }
            .padding(.horizontal, 24)

            PrimaryButton(
                title: isVerifying ? "Verifying…" : "Verify",
                enabled: enteredCode.count == 6 && !isVerifying,
                action: verify
            )
            .padding(.horizontal, 24)

            HStack(spacing: 18) {
                Button("Resend") { sendCode() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.iceBlue)

                Button("Use different number") {
                    codeSent = false
                    enteredCode = ""
                    codeError = nil
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.iceBlue)
            }
            .padding(.top, 4)

            BackTextButton(title: "Back", action: onBack)
        }
    }

    /// Asks Firebase to send a real SMS code to `phone`. Firebase normalises
    /// the number on the server (E.164 recommended).
    private func sendCode() {
        isSending = true
        codeError = nil
        Task {
            do {
                try await AuthService.shared.sendPhoneVerificationSMS(to: phone)
                await MainActor.run {
                    codeSent = true
                    enteredCode = ""
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    codeError = friendlySMSError(error)
                    isSending = false
                }
            }
        }
    }

    private func verify() {
        isVerifying = true
        codeError = nil
        Task {
            do {
                try await AuthService.shared.verifyPhoneCode(enteredCode)
                await MainActor.run {
                    isVerifying = false
                    onVerified()
                }
            } catch {
                await MainActor.run {
                    codeError = "Wrong code. Try again or send a new one."
                    isVerifying = false
                }
            }
        }
    }

    /// Map Firebase Phone Auth errors to readable strings.
    private func friendlySMSError(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == "FIRAuthErrorDomain" {
            switch ns.code {
            case 17042: return "That phone number doesn't look valid."
            case 17010: return "Too many attempts. Try again in a few minutes."
            case 17052: return "SMS quota exceeded for this Firebase project today."
            default: break
            }
        }
        return ns.localizedDescription
    }
}

// MARK: - Step 3: Skill Level (full page, vertical 1→5)

private struct SkillLevelStep: View {
    @Binding var skillLevel: Int
    var stepNumber: Int = 3
    var totalSteps: Int = 3
    let isSaving: Bool
    let onBack: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                StepHeader(step: stepNumber, total: totalSteps, title: "Your Skill Level", subtitle: "Be honest — better matches mean better games")

                VStack(spacing: 12) {
                    ForEach(SkillTier.all, id: \.level) { tier in
                        SkillTierRow(
                            tier: tier,
                            isSelected: skillLevel == tier.level,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    skillLevel = tier.level
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)

                PrimaryButton(
                    title: isSaving ? "Saving…" : "Finish",
                    enabled: !isSaving,
                    action: onFinish
                )
                .padding(.horizontal, 24)
                .padding(.top, 6)

                BackTextButton(title: "Back", action: onBack)

                Spacer().frame(height: 30)
            }
            .padding(.top, 16)
        }
    }
}

struct SkillTier {
    let level: Int
    let title: String
    let blurb: String
    let color: Color

    static let all: [SkillTier] = [
        .init(level: 1, title: "Beginner",
              blurb: "Struggling with skating and balance",
              color: Color(red: 0.46, green: 0.78, blue: 0.42)),
        .init(level: 2, title: "Low Intermediate",
              blurb: "Understanding the game, comfortable on skates",
              color: Color(red: 0.65, green: 0.80, blue: 0.32)),
        .init(level: 3, title: "Intermediate",
              blurb: "Solid skating and stick skills, learning positioning",
              color: Color(red: 0.95, green: 0.74, blue: 0.20)),
        .init(level: 4, title: "Advanced",
              blurb: "Strong skater with good vision and a quick release",
              color: Color(red: 0.94, green: 0.51, blue: 0.20)),
        .init(level: 5, title: "Best player",
              blurb: "Elite — moves the game, controls the puck, finishes",
              color: Color(red: 0.92, green: 0.28, blue: 0.28))
    ]
}

private struct SkillTierRow: View {
    let tier: SkillTier
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(tier.color.opacity(isSelected ? 1.0 : 0.18))
                        .frame(width: 46, height: 46)
                    Text("\(tier.level)")
                        .font(.title2.bold())
                        .foregroundStyle(isSelected ? .white : tier.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tier.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(tier.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(tier.color)
                }
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? tier.color : Color.black.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared step UI

struct StepHeader: View {
    let step: Int
    let total: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.iceBlue : Color.black.opacity(0.12))
                        .frame(width: i == step ? 28 : 18, height: 6)
                }
            }
            VStack(spacing: 4) {
                Text("Step \(step) of \(total)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.iceBlue)
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct PrimaryButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(enabled ? Color.iceBlue : Color.iceBlue.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!enabled)
    }
}

struct BackTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Compact horizontal skill picker (used by PostGameView etc.)

struct SkillSelector: View {
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SkillTier.all, id: \.level) { tier in
                Button {
                    withAnimation(.spring(response: 0.3)) { selected = tier.level }
                } label: {
                    VStack(spacing: 4) {
                        Text("\(tier.level)")
                            .font(.headline.bold())
                        Text(tier.title)
                            .font(.system(size: 9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selected == tier.level ? tier.color : Color.black.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(selected == tier.level ? .white : .primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selected == tier.level ? tier.color : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Form field (kept for shared use in GroupSetupView, etc.)

struct FormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .padding(12)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.primary)
        }
    }
}
