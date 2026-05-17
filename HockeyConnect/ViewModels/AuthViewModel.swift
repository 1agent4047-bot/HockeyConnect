import Foundation
import FirebaseAuth
import FirebaseCore
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var playerProfile: PlayerProfile?
    @Published var groupProfile: GroupProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var hasFirebaseUser = false

    private let auth = AuthService.shared
    private let db = FirestoreService.shared
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        guard FirebaseApp.app() != nil else {
            isLoading = false
            return
        }
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                await self?.loadUser(uid: user?.uid)
            }
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    private func loadUser(uid: String?) async {
        hasFirebaseUser = uid != nil
        errorMessage = nil      // clear any prior error before this load
        guard let uid else {
            currentUser = nil
            playerProfile = nil
            groupProfile = nil
            isLoading = false
            return
        }
        do {
            currentUser = try await db.fetchUser(uid: uid)
            if currentUser?.type == .player {
                playerProfile = try await db.fetchPlayerProfile(uid: uid)
            } else if currentUser?.type == .group {
                groupProfile = try await db.fetchGroupProfile(uid: uid)
            } else {
                // Brand-new Firebase user with no Firestore profile yet —
                // clear any stale profile state, do NOT surface as an error.
                playerProfile = nil
                groupProfile = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func finishPlayerSetup(
        displayName: String,
        phone: String,
        skillLevel: Int,
        age: Int,
        position: Position,
        playsBothWays: Bool
    ) async {
        guard let uid = auth.currentUID else { return }
        let user = AppUser(type: .player, displayName: displayName, phone: phone, createdAt: Date())
        let profile = PlayerProfile(
            skillLevel: skillLevel,
            age: age,
            availability: [],
            primaryPosition: position,
            playsBothWays: playsBothWays
        )
        do {
            try await db.createUser(user, uid: uid)
            try await db.createPlayerProfile(profile, uid: uid)
            currentUser = user
            playerProfile = profile
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finishGroupSetup(displayName: String, phone: String, groupName: String, rinkName: String, rinkAddress: String) async {
        guard let uid = auth.currentUID else { return }
        let user = AppUser(type: .group, displayName: displayName, phone: phone, createdAt: Date())
        let profile = GroupProfile(groupName: groupName, rinkName: rinkName, rinkAddress: rinkAddress)
        do {
            try await db.createUser(user, uid: uid)
            try await db.createGroupProfile(profile, uid: uid)
            currentUser = user
            groupProfile = profile
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateDisplayName(_ name: String) async {
        guard let uid = auth.currentUID else { return }
        do {
            try await db.updateDisplayName(uid: uid, displayName: name)
            currentUser?.displayName = name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateSkillLevel(_ level: Int) async {
        guard let uid = auth.currentUID else { return }
        do {
            try await db.updateSkillLevel(uid: uid, skillLevel: level)
            playerProfile?.skillLevel = level
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePosition(_ position: Position, playsBothWays: Bool) async {
        guard let uid = auth.currentUID else { return }
        do {
            try await db.updatePosition(uid: uid, position: position, playsBothWays: playsBothWays)
            playerProfile?.primaryPosition = position
            playerProfile?.playsBothWays = playsBothWays
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        try? auth.signOut()
        currentUser = nil
        playerProfile = nil
        groupProfile = nil
        hasFirebaseUser = false
    }

    /// Permanently deletes the user's auth record and all Firestore data.
    /// Throws so the calling view can present errors (e.g. Firebase requires
    /// recent re-auth for delete; the user may need to sign in again).
    func deleteAccount() async throws {
        try await auth.deleteCurrentAccount()
        currentUser = nil
        playerProfile = nil
        groupProfile = nil
        hasFirebaseUser = false
    }
}
