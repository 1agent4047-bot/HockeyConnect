import Foundation
import FirebaseFirestore

enum AccountType: String, Codable {
    case player
    case group
}

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var type: AccountType
    var displayName: String
    var phone: String
    var fcmToken: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, displayName, phone, fcmToken, createdAt
    }
}
