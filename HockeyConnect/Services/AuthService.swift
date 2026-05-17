import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    var isConfigured: Bool { FirebaseApp.app() != nil }
    var currentFirebaseUser: FirebaseAuth.User? {
        guard isConfigured else { return nil }
        return Auth.auth().currentUser
    }
    var currentUID: String? { currentFirebaseUser?.uid }

    private var currentNonce: String?

    private func requireFirebase() throws {
        guard isConfigured else { throw AuthError.missingConfig }
    }

    // MARK: - Apple Sign In

    func startAppleSignIn() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    func handleAppleCredential(_ result: Result<ASAuthorization, Error>) async throws -> FirebaseAuth.User {
        let auth = try result.get()
        guard
            let cred = auth.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = cred.identityToken,
            let token = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else { throw AuthError.invalidCredential }

        try requireFirebase()
        let firebaseCred = OAuthProvider.appleCredential(
            withIDToken: token,
            rawNonce: nonce,
            fullName: cred.fullName
        )
        let result2 = try await Auth.auth().signIn(with: firebaseCred)
        return result2.user
    }

    // MARK: - Google Sign In

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> FirebaseAuth.User {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingConfig
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }
        let cred = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: cred)
        return authResult.user
    }

    // MARK: - Email / Password
    //
    // Firebase Auth never receives or stores plaintext passwords on our side:
    // the SDK transmits credentials over TLS to Google's auth servers, which
    // hash them with scrypt + a per-user salt. We never see the raw password
    // beyond the in-memory String the user types.

    func signInWithEmail(_ email: String, password: String) async throws -> FirebaseAuth.User {
        try requireFirebase()
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            if !result.user.isEmailVerified {
                try? await result.user.sendEmailVerification()
            }
            return result.user
        } catch let nsError as NSError {
            // Map Firebase's opaque errors to clear user-facing strings.
            let code = AuthErrorCode(rawValue: nsError.code)
            switch code {
            case .userNotFound, .invalidEmail:
                throw AuthError.accountNotFound
            case .wrongPassword, .invalidCredential:
                throw AuthError.wrongPassword
            case .networkError:
                throw AuthError.network
            default:
                throw nsError
            }
        }
    }

    func createAccountWithEmail(_ email: String, password: String) async throws -> FirebaseAuth.User {
        try requireFirebase()
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try? await result.user.sendEmailVerification()
            return result.user
        } catch let nsError as NSError {
            let code = AuthErrorCode(rawValue: nsError.code)
            switch code {
            case .emailAlreadyInUse:
                throw AuthError.emailAlreadyInUse
            case .invalidEmail:
                throw AuthError.invalidEmail
            case .weakPassword:
                throw AuthError.weakPassword
            default:
                throw nsError
            }
        }
    }

    // MARK: - Email verification code (6-digit)
    //
    // Same dev-only pattern as the phone code: we generate locally and show in
    // the UI for now. Production wiring is a Cloud Function that:
    //   1) Generates the code and stores a salted hash in Firestore with TTL
    //   2) Sends the email via SendGrid/Mailgun (or Firebase Trigger Email)
    //   3) Returns success; the app calls a separate verify endpoint that
    //      compares the hash.
    // Until that backend exists, the code is displayed on-device so the flow
    // is testable end-to-end.

    func generateEmailVerificationCode(for email: String) -> String {
        let code = String(format: "%06d", Int.random(in: 0...999_999))
        #if DEBUG
        print("✉️  [EmailVerify] Sent code \(code) to \(email)")
        #endif
        return code
    }

    func resendVerificationEmail(to email: String, password: String) async throws {
        try requireFirebase()
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        try await result.user.sendEmailVerification()
        try? Auth.auth().signOut()
    }

    // MARK: - Sign Out

    func signOut() throws {
        guard isConfigured else { return }
        try Auth.auth().signOut()
    }

    // MARK: - Phone Verification (Firebase Phone Auth — REAL SMS)
    //
    // Firebase generates the SMS code on its servers, sends it via carrier,
    // and verifies the code we hand back. We never see the code in plaintext
    // beyond the user typing it in. Requires:
    //   • APNs auth key uploaded to Firebase Cloud Messaging  (done)
    //   • Phone provider enabled in Firebase Authentication   (done)
    //   • Real device for silent-push verification (simulator falls back to
    //     reCAPTCHA web flow OR a Firebase Console test phone number)
    //
    // The verificationID from verifyPhoneNumber is stored privately so the
    // verify call later can use it without exposing it to the UI.
    private var phoneVerificationID: String?

    /// Triggers Firebase to SMS a 6-digit code to `phone` (E.164 format
    /// recommended, e.g. "+16025551234"). Throws on rate limit, invalid
    /// number, missing APNs config, etc.
    func sendPhoneVerificationSMS(to phone: String) async throws {
        try requireFirebase()
        let id = try await PhoneAuthProvider.provider()
            .verifyPhoneNumber(phone, uiDelegate: nil)
        phoneVerificationID = id
    }

    /// Verifies the 6-digit code the user typed. If a Firebase user is
    /// already signed in (Apple/Google/email), the phone is *linked* to that
    /// account. Otherwise this signs the user in via phone alone.
    func verifyPhoneCode(_ code: String) async throws {
        try requireFirebase()
        guard let id = phoneVerificationID else {
            throw AuthError.invalidCredential
        }
        let credential = PhoneAuthProvider.provider()
            .credential(withVerificationID: id, verificationCode: code)

        if let current = Auth.auth().currentUser {
            _ = try await current.link(with: credential)
        } else {
            _ = try await Auth.auth().signIn(with: credential)
        }
        phoneVerificationID = nil
    }

    // MARK: - Account Deletion
    //
    // App Store guideline 5.1.1(v) requires that if users can sign up in the
    // app, they must be able to delete their account in the app. This nukes
    // the Firestore documents and then the Firebase auth record.

    func deleteCurrentAccount() async throws {
        try requireFirebase()
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        // Best-effort Firestore cleanup. If Firestore writes fail (e.g. user
        // never finished onboarding), still proceed with auth deletion so the
        // user isn't stuck in a half-deleted state.
        await FirestoreService.shared.deleteUserDocuments(uid: uid)
        try await user.delete()
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: LocalizedError {
    case invalidCredential
    case missingConfig
    case emailNotVerified
    case verificationSent
    case accountNotFound
    case wrongPassword
    case emailAlreadyInUse
    case invalidEmail
    case weakPassword
    case network

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid credentials. Please try again."
        case .missingConfig: return "Sign-in is not configured yet. Please contact support."
        case .emailNotVerified: return "Please verify your email — we just resent the verification link."
        case .verificationSent: return "Account created. Check your email for a verification link, then sign in."
        case .accountNotFound: return "Account not found. Create an account to get started."
        case .wrongPassword: return "Incorrect password. Try again or reset it."
        case .emailAlreadyInUse: return "An account already exists for that email — try signing in."
        case .invalidEmail: return "That doesn't look like a valid email address."
        case .weakPassword: return "Password is too weak. Use at least 6 characters."
        case .network: return "Network error. Check your connection and try again."
        }
    }
}
