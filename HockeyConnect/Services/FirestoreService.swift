import Foundation
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    private lazy var db: Firestore = Firestore.firestore()

    // MARK: - Users

    func createUser(_ user: AppUser, uid: String) async throws {
        try db.collection("users").document(uid).setData(from: user)
    }

    /// Returns nil (not an error) when the user document does not exist yet.
    /// `getDocument(as:)` throws "data couldn't be read because it is missing"
    /// if the doc is absent — we treat that as a clean "no profile yet".
    func fetchUser(uid: String) async throws -> AppUser? {
        let snap = try await db.collection("users").document(uid).getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: AppUser.self)
    }

    func updateFCMToken(uid: String, token: String) async throws {
        try await db.collection("users").document(uid).updateData(["fcmToken": token])
    }

    // MARK: - Player Profiles

    func createPlayerProfile(_ profile: PlayerProfile, uid: String) async throws {
        try db.collection("players").document(uid).setData(from: profile)
    }

    func fetchPlayerProfile(uid: String) async throws -> PlayerProfile? {
        let snap = try await db.collection("players").document(uid).getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: PlayerProfile.self)
    }

    func updateAvailability(uid: String, slots: [AvailabilitySlot]) async throws {
        let encoded = try Firestore.Encoder().encode(slots)
        try await db.collection("players").document(uid).updateData(["availability": encoded])
    }

    func updateDisplayName(uid: String, displayName: String) async throws {
        try await db.collection("users").document(uid).updateData(["displayName": displayName])
    }

    func updateSkillLevel(uid: String, skillLevel: Int) async throws {
        try await db.collection("players").document(uid).updateData(["skillLevel": skillLevel])
    }

    func updatePosition(uid: String, position: Position, playsBothWays: Bool) async throws {
        try await db.collection("players").document(uid).updateData([
            "primaryPosition": position.rawValue,
            "playsBothWays": playsBothWays
        ])
    }

    /// Best-effort deletion of all docs belonging to the user across the
    /// users/players/groups collections. Used during account deletion.
    /// Errors are swallowed because we want auth deletion to proceed even if
    /// one of the collections has no document for this uid.
    func deleteUserDocuments(uid: String) async {
        for col in ["users", "players", "groups"] {
            try? await db.collection(col).document(uid).delete()
        }
    }

    // MARK: - Group Profiles

    func createGroupProfile(_ profile: GroupProfile, uid: String) async throws {
        try db.collection("groups").document(uid).setData(from: profile)
    }

    func fetchGroupProfile(uid: String) async throws -> GroupProfile? {
        let snap = try await db.collection("groups").document(uid).getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: GroupProfile.self)
    }

    // MARK: - Games

    func createGame(_ game: Game) async throws -> String {
        let ref = try db.collection("games").addDocument(from: game)
        return ref.documentID
    }

    func gamesForPlayer(skillLevel: Int, listener: @escaping ([Game]) -> Void) -> ListenerRegistration {
        db.collection("games")
            .whereField("skillLevelRequired", isEqualTo: skillLevel)
            .whereField("status", isEqualTo: GameStatus.open.rawValue)
            .order(by: "date")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let games = docs.compactMap { try? $0.data(as: Game.self) }
                listener(games)
            }
    }

    func gamesForGroup(groupId: String, listener: @escaping ([Game]) -> Void) -> ListenerRegistration {
        db.collection("games")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let games = docs.compactMap { try? $0.data(as: Game.self) }
                listener(games)
            }
    }

    func applyToGame(gameId: String, playerId: String) async throws {
        try await db.collection("games").document(gameId).updateData([
            "applicantIds": FieldValue.arrayUnion([playerId])
        ])
    }

    func selectPlayer(gameId: String, playerId: String) async throws {
        let ref = db.collection("games").document(gameId)
        _ = try await db.runTransaction { transaction, _ in
            guard let snap = try? transaction.getDocument(ref),
                  let game = try? snap.data(as: Game.self) else { return nil }
            transaction.updateData([
                "selectedPlayerIds": FieldValue.arrayUnion([playerId]),
                "spotsAvailable": max(0, game.spotsAvailable - 1),
                "status": game.spotsAvailable <= 1 ? GameStatus.filled.rawValue : GameStatus.open.rawValue
            ], forDocument: ref)
            return nil
        }
    }

    func recordPayment(_ record: PaymentRecord, uid: String) async throws {
        try db.collection("payments").addDocument(from: record)
    }

    func fetchApplicantProfiles(playerIds: [String]) async throws -> [(AppUser, PlayerProfile)] {
        var results: [(AppUser, PlayerProfile)] = []
        for pid in playerIds {
            if let user = try await fetchUser(uid: pid),
               let profile = try await fetchPlayerProfile(uid: pid) {
                results.append((user, profile))
            }
        }
        return results
    }
}
