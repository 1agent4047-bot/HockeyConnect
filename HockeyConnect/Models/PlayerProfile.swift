import Foundation
import FirebaseFirestore

struct AvailabilitySlot: Codable, Identifiable {
    var id = UUID().uuidString
    var dayOfWeek: Int   // 1=Sunday … 7=Saturday
    var startHour: Int   // 0–23
    var endHour: Int
}

/// Where a player skates. Goalie is exclusive — goalies never skate out, and
/// skaters never play net. Forward/Defense players may opt-in to playing the
/// other side via `playsBothWays`.
enum Position: String, Codable, CaseIterable {
    case forward
    case defense
    case goalie

    var label: String {
        switch self {
        case .forward: return "Forward"
        case .defense: return "Defense"
        case .goalie:  return "Goalie"
        }
    }
}

struct PlayerProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var skillLevel: Int          // 1–5
    var age: Int
    var availability: [AvailabilitySlot]
    /// Primary position the player suits up at. Defaults to .forward for any
    /// legacy profiles created before this field existed.
    var primaryPosition: Position = .forward
    /// Skater-only flexibility: a forward who's comfortable playing D, or a
    /// D who can move up to forward. Ignored when `primaryPosition == .goalie`.
    var playsBothWays: Bool = false

    var skillLabel: String {
        switch skillLevel {
        case 1: return "Beginner"
        case 2: return "Novice"
        case 3: return "Intermediate"
        case 4: return "Advanced"
        case 5: return "Elite"
        default: return "Unknown"
        }
    }

    /// All positions this player can fill in a game roster — used by the feed
    /// filter to decide whether the player should see a given game.
    var eligiblePositions: Set<Position> {
        switch primaryPosition {
        case .goalie:
            return [.goalie]
        case .forward:
            return playsBothWays ? [.forward, .defense] : [.forward]
        case .defense:
            return playsBothWays ? [.defense, .forward] : [.defense]
        }
    }
}
