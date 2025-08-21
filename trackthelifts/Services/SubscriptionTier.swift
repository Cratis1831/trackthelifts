import Foundation

enum SubscriptionTier: String, CaseIterable {
    case free = "free"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Premium"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "Basic workout tracking",
                "Exercise library",
                "Local data storage",
                "Workout history"
            ]
        case .premium:
            return [
                "Everything in Free",
                "iCloud sync across devices",
                "Automatic backup",
                "Data restoration"
            ]
        }
    }
    
    var canUseiCloudSync: Bool {
        switch self {
        case .free:
            return false
        case .premium:
            return true
        }
    }
}

struct PremiumFeature {
    static let iCloudSync = "icloud_sync"
}

enum RevenueCatError: Error, LocalizedError {
    case notConfigured
    case purchaseFailed(Error)
    case restoreFailed(Error)
    case invalidProduct
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "RevenueCat is not configured"
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription)"
        case .invalidProduct:
            return "Invalid product"
        case .userCancelled:
            return "User cancelled the purchase"
        }
    }
}