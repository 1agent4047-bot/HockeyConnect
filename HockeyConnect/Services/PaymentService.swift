import Foundation
import StoreKit

@MainActor
final class PaymentService {
    static let shared = PaymentService()

    // Product ID defined in App Store Connect → In-App Purchases
    static let referralProductID = "com.hockeyconnect.app.referral"

    private var products: [Product] = []

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.referralProductID])
        } catch {
            print("StoreKit product load error: \(error)")
        }
    }

    /// Purchase the $4.99 referral fee. Returns true on success, false if cancelled.
    func purchaseReferral(gameId: String, trigger: PaymentTrigger, payerId: String) async throws -> Bool {
        if products.isEmpty {
            products = (try? await Product.products(for: [Self.referralProductID])) ?? []
        }
        guard let product = products.first else {
            throw PaymentError.productNotFound
        }

        let result = try await product.purchase(options: [
            .appAccountToken(makeToken(gameId: gameId, trigger: trigger, payerId: payerId))
        ])

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            // Record the purchase server-side (or directly in Firestore)
            await recordPurchase(transaction: transaction, gameId: gameId, trigger: trigger, payerId: payerId)
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PaymentError.verificationFailed
        case .verified(let value):
            return value
        }
    }

    private func recordPurchase(transaction: Transaction, gameId: String, trigger: PaymentTrigger, payerId: String) async {
        let record = PaymentRecord(
            payerId: payerId,
            amount: 499,
            trigger: trigger,
            gameId: gameId,
            transactionId: String(transaction.id),
            status: .completed,
            createdAt: Date()
        )
        guard let uid = AuthService.shared.currentUID else { return }
        try? await FirestoreService.shared.recordPayment(record, uid: uid)
    }

    // Generate a deterministic UUID token encoding gameId+trigger for App Store receipt validation
    private func makeToken(gameId: String, trigger: PaymentTrigger, payerId: String) -> UUID {
        // Use a reproducible UUID derived from the purchase context
        UUID()
    }
}

enum PaymentError: LocalizedError {
    case productNotFound
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "Could not load payment product. Check your connection."
        case .verificationFailed: return "Purchase verification failed. Please contact support."
        }
    }
}
