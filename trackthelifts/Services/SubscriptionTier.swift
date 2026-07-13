import Foundation

enum SubscriptionTier: String, CaseIterable, Identifiable {
    case free
    case pro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "Unlimited workout logging",
                "Complete workout history",
                "Built-in exercise library",
                "Previous-session values",
                "Automatic rest timer",
                "Basic PR detection and celebrations",
                "Basic progress dashboard",
                "Pounds/kilograms, reminders, and CSV export",
            ]
        case .pro:
            return ["Everything in Free"] + ProFeature.allCases.map(\.title)
        }
    }
}

enum ProFeature: String, CaseIterable, Identifiable {
    case unlimitedRoutines
    case advancedProgress
    case effortTracking
    case supersets
    case accentThemes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedRoutines: return "Unlimited Routines"
        case .advancedProgress: return "Advanced Progress Analytics"
        case .effortTracking: return "RPE and RIR Tracking"
        case .supersets: return "Supersets"
        case .accentThemes: return "Every Accent Theme"
        }
    }

    var description: String {
        switch self {
        case .unlimitedRoutines:
            return "Create as many reusable workout routines as you need. Free includes up to three."
        case .advancedProgress:
            return "See detailed volume and estimated one-rep-max trends over time."
        case .effortTracking:
            return "Track how hard each set feels with optional RPE or reps-in-reserve ratings."
        case .supersets:
            return "Pair exercises into supersets while building routines or logging workouts."
        case .accentThemes:
            return "Personalize Track The Lifts with every available accent color."
        }
    }

    var systemImage: String {
        switch self {
        case .unlimitedRoutines: return "list.bullet.rectangle.portrait"
        case .advancedProgress: return "chart.xyaxis.line"
        case .effortTracking: return "gauge.with.dots.needle.50percent"
        case .supersets: return "link"
        case .accentThemes: return "paintpalette.fill"
        }
    }
}

enum SubscriptionAccessPolicy {
    static let freeRoutineLimit = 3

    static func canAccess(_ feature: ProFeature, tier: SubscriptionTier) -> Bool {
        tier == .pro
    }

    static func effectiveTier(
        entitlementTier: SubscriptionTier,
        debugOverride: SubscriptionTier?
    ) -> SubscriptionTier {
        debugOverride ?? entitlementTier
    }

    static func canCreateRoutine(existingCount: Int, tier: SubscriptionTier) -> Bool {
        tier == .pro || existingCount < freeRoutineLimit
    }

    static func canCopyRoutineSource(
        existingCount: Int,
        sourceContainsSupersets: Bool,
        tier: SubscriptionTier
    ) -> Bool {
        canCreateRoutine(existingCount: existingCount, tier: tier)
            && (tier == .pro || !sourceContainsSupersets)
    }
}

enum RevenueCatError: Error, LocalizedError {
    case notConfigured
    case purchaseFailed(Error)
    case restoreFailed(Error)
    case invalidProduct
    case userCancelled
    case offeringsLoadFailed(Error)
    case noOfferingsAvailable

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
        case .offeringsLoadFailed(let error):
            return "Couldn't load subscription plans: \(error.localizedDescription)"
        case .noOfferingsAvailable:
            return "No subscription plans are available right now."
        }
    }
}
