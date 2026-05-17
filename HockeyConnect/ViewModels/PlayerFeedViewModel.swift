import Foundation
import FirebaseFirestore

@MainActor
final class PlayerFeedViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var paymentState: PaymentState = .idle
    @Published var errorMessage: String?

    enum PaymentState {
        case idle, processing, success, failed(String)
    }

    private let db = FirestoreService.shared
    private var listener: ListenerRegistration?

    /// Subscribes to all open games at the given skill level and filters
    /// client-side to only those needing a position the player can fill.
    /// Position filtering is done in-memory because Firestore can't query a
    /// dynamic "any of these positions has >0 spots" condition cleanly.
    func startListening(skillLevel: Int, eligiblePositions: Set<Position>) {
        listener = db.gamesForPlayer(skillLevel: skillLevel) { [weak self] games in
            self?.games = games.filter { $0.matches(positions: eligiblePositions) }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func joinGame(_ game: Game, playerId: String) async {
        guard let gameId = game.id else { return }
        paymentState = .processing
        do {
            let success = try await PaymentService.shared.purchaseReferral(
                gameId: gameId, trigger: .playerJoin, payerId: playerId
            )
            if success {
                try await db.applyToGame(gameId: gameId, playerId: playerId)
                paymentState = .success
            } else {
                paymentState = .idle
            }
        } catch {
            paymentState = .failed(error.localizedDescription)
        }
    }
}
