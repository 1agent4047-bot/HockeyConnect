import Foundation
import FirebaseFirestore

enum GameStatus: String, Codable {
    case open
    case filled
    case cancelled
}

struct Game: Identifiable, Codable {
    @DocumentID var id: String?
    var groupId: String
    var groupName: String
    var rinkName: String
    var date: Date
    var skillLevelRequired: Int
    var spotsTotal: Int
    var spotsAvailable: Int
    var applicantIds: [String]
    var selectedPlayerIds: [String]
    var status: GameStatus

    // Per-position openings. Defaults handle pre-existing games written
    // before position support existed.
    var forwardSpots: Int = 0
    var defenseSpots: Int = 0
    var goalieSpots: Int = 0

    var isFull: Bool { spotsAvailable <= 0 }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// True if this game has at least one open spot for any position the
    /// player can fill.
    func matches(positions: Set<Position>) -> Bool {
        for p in positions {
            switch p {
            case .forward: if forwardSpots > 0 { return true }
            case .defense: if defenseSpots > 0 { return true }
            case .goalie:  if goalieSpots > 0  { return true }
            }
        }
        // Fall back to the flat spotsAvailable for legacy games that don't
        // have the per-position breakdown filled in yet.
        return forwardSpots == 0 && defenseSpots == 0 && goalieSpots == 0
            && spotsAvailable > 0
    }
}
