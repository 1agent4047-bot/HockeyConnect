import Foundation
import FirebaseFirestore

@MainActor
final class GroupDashboardViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var applicants: [(AppUser, PlayerProfile)] = []
    @Published var paymentState: PaymentState = .idle
    @Published var errorMessage: String?

    enum PaymentState {
        case idle, processing, success, failed(String)
    }

    private let db = FirestoreService.shared
    private var listener: ListenerRegistration?

    func startListening(groupId: String) {
        listener = db.gamesForGroup(groupId: groupId) { [weak self] games in
            self?.games = games
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func postGame(
        groupId: String,
        groupName: String,
        rinkName: String,
        date: Date,
        skillLevel: Int,
        forwardSpots: Int,
        defenseSpots: Int,
        goalieSpots: Int
    ) async {
        let total = forwardSpots + defenseSpots + goalieSpots
        let game = Game(
            groupId: groupId,
            groupName: groupName,
            rinkName: rinkName,
            date: date,
            skillLevelRequired: skillLevel,
            spotsTotal: total,
            spotsAvailable: total,
            applicantIds: [],
            selectedPlayerIds: [],
            status: .open,
            forwardSpots: forwardSpots,
            defenseSpots: defenseSpots,
            goalieSpots: goalieSpots
        )
        do {
            _ = try await db.createGame(game)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadApplicants(for game: Game) async {
        do {
            applicants = try await db.fetchApplicantProfiles(playerIds: game.applicantIds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectPlayer(game: Game, playerId: String, groupId: String) async {
        guard let gameId = game.id else { return }
        paymentState = .processing
        do {
            let success = try await PaymentService.shared.purchaseReferral(
                gameId: gameId, trigger: .groupSelect, payerId: groupId
            )
            if success {
                try await db.selectPlayer(gameId: gameId, playerId: playerId)
                paymentState = .success
            } else {
                paymentState = .idle
            }
        } catch {
            paymentState = .failed(error.localizedDescription)
        }
    }
}
