import SwiftUI
import AuthenticationServices

// MARK: - AuthView
//
// Single entry point for sign-in and sign-up. On sign-UP via email we add a
// 6-digit code verification screen before completing — same UX as the phone
// step in player/group setup. Apple and Google complete in one tap and skip
// the email-code step entirely.
//
// Phase machine:
//   .credentials  → enter Apple/Google or email+password
//   .emailCode    → (sign-up email only) enter 6-digit code mailed to address
//
// Completion calls `onSuccess()`, which advances to the AccountType screen.

enum AuthPhase: Equatable {
    case credentials
    case emailCode
}

struct AuthView: View {
    let mode: AuthMode
    let onSuccess: () -> Void

    @EnvironmentObject var authVM: AuthViewModel
    @State private var phase: AuthPhase = .credentials
    @State private var isEmailMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var infoMessage: String?

    // Email-code state
    @State private var expectedEmailCode: String?
    @State private var enteredEmailCode = ""
    @State private var emailCodeError = false
    @State private var devShowEmailCode: String?

    private var isSignUp: Bool { mode == .signUp }
    private var title: String { isSignUp ? "Create Your Account" : "Welcome Back" }
    private var subtitle: String { isSignUp ? "Choose how you want to sign up" : "Choose how you want to sign in" }

    var body: some View {
        Group {
            switch phase {
            case .credentials:
                credentialsView
            case .emailCode:
                emailCodeView
            }
        }
        .onAppear {
            authVM.errorMessage = nil
            infoMessage = nil
        }
    }

    // MARK: - Credentials phase (Apple / Google / email-password)

    private var credentialsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 28)

                VStack(spacing: 10) {
                    Image(systemName: isSignUp ? "person.fill.badge.plus" : "person.fill.checkmark")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.iceBlue)
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                VStack(spacing: 14) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            let req = AuthService.shared.startAppleSignIn()
                            request.requestedScopes = req.requestedScopes
                            request.nonce = req.nonce
                        },
                        onCompletion: { result in
                            Task {
                                do {
                                    _ = try await AuthService.shared.handleAppleCredential(result)
                                    onSuccess()
                                } catch {
                                    authVM.errorMessage = friendlyAppleError(error)
                                }
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    SocialButton(
                        icon: "g.circle.fill",
                        title: "\(isSignUp ? "Sign up" : "Continue") with Google",
                        color: Color.navyDark
                    ) {
                        Task { await signInGoogle() }
                    }

                    HStack {
                        VStack { Divider() }.overlay(Color.black.opacity(0.1))
                        Text("or").font(.caption).foregroundStyle(.secondary)
                        VStack { Divider() }.overlay(Color.black.opacity(0.1))
                    }
                    .padding(.vertical, 4)

                    if !isEmailMode {
                        EmailToggleButton(isSignUp: isSignUp) {
                            withAnimation { isEmailMode = true }
                        }
                    } else {
                        EmailFields(
                            email: $email,
                            password: $password,
                            isSignUp: isSignUp,
                            isLoading: isLoading,
                            onSubmit: { Task { await submitEmail() } }
                        )
                    }
                }
                .padding(.horizontal, 24)

                if let info = infoMessage {
                    StatusBanner(message: info, kind: .info)
                        .padding(.horizontal, 24)
                }

                if let err = authVM.errorMessage {
                    StatusBanner(message: err, kind: .error)
                        .padding(.horizontal, 24)
                }

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                    Text("Encrypted end-to-end · Passwords never stored in plaintext")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer().frame(height: 24)
            }
        }
    }

    // MARK: - Email code phase (sign-up only)

    private var emailCodeView: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer().frame(height: 20)

                VStack(spacing: 10) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.iceBlue)
                    Text("Check your email")
                        .font(.largeTitle.bold())
                    Text("We sent a 6-digit code to\n\(email)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                GlassCard {
                    VStack(spacing: 14) {
                        Text("6-Digit Code")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TextField("000000", text: $enteredEmailCode)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .tracking(8)
                            .multilineTextAlignment(.center)
                            .padding(14)
                            .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                            .onChange(of: enteredEmailCode) { _, newValue in
                                enteredEmailCode = String(newValue.filter(\.isNumber).prefix(6))
                                emailCodeError = false
                            }

                        if emailCodeError {
                            Text("Wrong code. Try again, or resend a new one.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if let dev = devShowEmailCode {
                            Text("Dev: code is \(dev)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                }
                .padding(.horizontal, 24)

                PrimaryButton(
                    title: "Verify",
                    enabled: enteredEmailCode.count == 6 && !isLoading,
                    action: verifyEmailCode
                )
                .padding(.horizontal, 24)

                Button("Resend code") { sendEmailCode() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.iceBlue)

                BackTextButton(title: "Use a different email") {
                    withAnimation { phase = .credentials }
                    expectedEmailCode = nil
                    enteredEmailCode = ""
                    devShowEmailCode = nil
                }

                Spacer().frame(height: 30)
            }
        }
    }

    // MARK: - Actions

    private func signInGoogle() async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        authVM.errorMessage = nil
        do {
            _ = try await AuthService.shared.signInWithGoogle(presenting: root)
            onSuccess()
        } catch {
            authVM.errorMessage = error.localizedDescription
        }
    }

    private func submitEmail() async {
        authVM.errorMessage = nil
        infoMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if isSignUp {
                _ = try await AuthService.shared.createAccountWithEmail(email, password: password)
                // Move to email-code verification BEFORE proceeding.
                sendEmailCode()
                withAnimation(.spring(response: 0.45)) { phase = .emailCode }
            } else {
                _ = try await AuthService.shared.signInWithEmail(email, password: password)
                onSuccess()
            }
        } catch {
            authVM.errorMessage = error.localizedDescription
        }
    }

    private func sendEmailCode() {
        let code = AuthService.shared.generateEmailVerificationCode(for: email)
        expectedEmailCode = code
        enteredEmailCode = ""
        emailCodeError = false
        // DEV-ONLY: see comment in PhoneVerifyStep.sendCode. Strip before release.
        devShowEmailCode = code
    }

    private func verifyEmailCode() {
        guard enteredEmailCode == expectedEmailCode else {
            emailCodeError = true
            return
        }
        onSuccess()
    }

    /// Apple Sign-In returns generic errors on the simulator. Translate the
    /// common ones into actionable messages.
    private func friendlyAppleError(_ error: Error) -> String {
        let ns = error as NSError
        // 1000 = canceled or not available on simulator
        if ns.code == 1000 {
            return "Apple Sign-In is only available on a real device with an iCloud account."
        }
        return error.localizedDescription
    }
}

extension AuthError: Equatable {
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredential, .invalidCredential),
             (.missingConfig, .missingConfig),
             (.emailNotVerified, .emailNotVerified),
             (.verificationSent, .verificationSent),
             (.accountNotFound, .accountNotFound),
             (.wrongPassword, .wrongPassword),
             (.emailAlreadyInUse, .emailAlreadyInUse),
             (.invalidEmail, .invalidEmail),
             (.weakPassword, .weakPassword),
             (.network, .network):
            return true
        default:
            return false
        }
    }
}

// MARK: - Subviews

private struct SocialButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EmailToggleButton: View {
    let isSignUp: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.title3)
                Text("\(isSignUp ? "Sign up" : "Continue") with Email")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Color.iceBlue, Color(red: 0.13, green: 0.42, blue: 0.65)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct EmailFields: View {
    @Binding var email: String
    @Binding var password: String
    let isSignUp: Bool
    let isLoading: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.12), lineWidth: 1))
                .foregroundStyle(.primary)

            SecureField("Password (min 6 characters)", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.12), lineWidth: 1))
                .foregroundStyle(.primary)

            if isSignUp {
                Text("We'll send a 6-digit verification code to that email.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: onSubmit) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [Color.iceBlue, Color(red: 0.13, green: 0.42, blue: 0.65)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoading || email.isEmpty || password.count < 6)
            .opacity((email.isEmpty || password.count < 6) ? 0.6 : 1.0)
        }
    }
}

private struct StatusBanner: View {
    enum Kind { case info, error }
    let message: String
    let kind: Kind

    private var color: Color { kind == .info ? Color.iceBlue : .red }
    private var icon: String { kind == .info ? "info.circle.fill" : "exclamationmark.triangle.fill" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
