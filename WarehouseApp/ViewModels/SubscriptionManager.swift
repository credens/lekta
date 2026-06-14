import Foundation
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    @Published private(set) var tier: SubscriptionTier = .free

    private let key = "subscription_tier_v1"

    init() { load() }

    // MARK: - Limit checks

    func canAddProduct(currentCount: Int) -> Bool {
        currentCount < tier.maxProducts
    }

    func productsRemaining(currentCount: Int) -> Int {
        max(0, tier.maxProducts - currentCount)
    }

    // MARK: - Upgrade (stub — wire to StoreKit / backend when ready)

    func setTier(_ newTier: SubscriptionTier) {
        tier = newTier
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded: SubscriptionTier = SecureStorage.decryptCodable(data) else { return }
        tier = decoded
    }

    private func save() {
        guard let data = SecureStorage.encryptCodable(tier) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
