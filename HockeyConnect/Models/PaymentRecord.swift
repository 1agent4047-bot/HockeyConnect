import Foundation
import FirebaseFirestore

enum PaymentTrigger: String, Codable {
    case playerJoin = "player_join"
    case groupSelect = "group_select"
}

enum PaymentStatus: String, Codable {
    case pending
    case completed
    case failed
}

struct PaymentRecord: Identifiable, Codable {
    @DocumentID var id: String?
    var payerId: String
    var amount: Int              // cents — always 499 ($4.99 StoreKit IAP)
    var trigger: PaymentTrigger
    var gameId: String
    /// StoreKit Transaction.id (was named for Stripe in an earlier plan;
    /// payments now go through Apple's In-App Purchase, so this is the
    /// StoreKit 2 transaction identifier).
    var transactionId: String
    var status: PaymentStatus
    var createdAt: Date
}
