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
                "Unlimited routines and supersets",
                "RPE and RIR tracking",
                "Progress charts and personal records",
                "Every accent theme",
                "iCloud workout sync and backup",
                "Preview calorie tracking with a few manual logs",
            ]
        case .pro:
            return ["Everything in Free"] + ProFeature.merchandised.map(\.title)
        }
    }
}

enum ProFeature: String, CaseIterable, Identifiable {
    case calorieTracking
    case foodSearch
    case barcodeScan
    case aiDescribe
    case foodPhoto
    case labelScan
    case nutritionBackup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calorieTracking: return "Calorie & Macro Tracking"
        case .foodSearch: return "Food Database Search"
        case .barcodeScan: return "Barcode Food Scanning"
        case .aiDescribe: return "AI Meal Descriptions"
        case .foodPhoto: return "Food Photo Recognition"
        case .labelScan: return "Nutrition Facts Label Scanning"
        case .nutritionBackup: return "Secure Nutrition Backup"
        }
    }

    var description: String {
        switch self {
        case .calorieTracking:
            return "Log meals, hit calorie and macro targets, and see your day at a glance."
        case .foodSearch:
            return "Search a growing food catalogue instead of typing every meal from scratch."
        case .barcodeScan:
            return "Scan a packaged product and log it without hunting for the Nutrition Facts panel."
        case .aiDescribe:
            return "Describe what you ate in plain language and confirm the foods before logging."
        case .foodPhoto:
            return "Photograph a meal, confirm the foods and portions, then add it to your diary."
        case .labelScan:
            return "Snap a Nutrition Facts label when a product is missing from the database."
        case .nutritionBackup:
            return "Back up your food history through ForgeLyte so it can be restored on a new iPhone. Not stored in iCloud."
        }
    }

    var systemImage: String {
        switch self {
        case .calorieTracking: return "fork.knife"
        case .foodSearch: return "magnifyingglass"
        case .barcodeScan: return "barcode.viewfinder"
        case .aiDescribe: return "text.bubble.fill"
        case .foodPhoto: return "camera.fill"
        case .labelScan: return "doc.text.viewfinder"
        case .nutritionBackup: return "externaldrive.fill.badge.checkmark"
        }
    }

    var onboardingCaption: String {
        switch self {
        case .calorieTracking: return "Calories and macros"
        case .foodSearch: return "Search foods quickly"
        case .barcodeScan: return "Scan packaged foods"
        case .aiDescribe: return "Describe a meal"
        case .foodPhoto: return "Photograph meals"
        case .labelScan: return "Read Nutrition Facts"
        case .nutritionBackup: return "Restore on a new iPhone"
        }
    }

    static var merchandised: [ProFeature] {
        allCases.filter { $0 != .foodPhoto }
    }

    /// Every nutrition Pro feature is included in an active StoreKit trial.
    var isIncludedInFreeTrial: Bool { true }

    static var trialIncluded: [ProFeature] {
        merchandised
    }
}

enum SubscriptionAccessPolicy {
    static func canAccess(
        _ feature: ProFeature,
        tier: SubscriptionTier,
        isInFreeTrial: Bool = false
    ) -> Bool {
        _ = isInFreeTrial
        return tier == .pro
    }

    static func effectiveTier(
        entitlementTier: SubscriptionTier,
        debugOverride: SubscriptionTier?
    ) -> SubscriptionTier {
        debugOverride ?? entitlementTier
    }

    static func userCreatedRoutineCount(from templates: [WorkoutTemplate]) -> Int {
        templates.filter { !$0.isStarterRoutine }.count
    }

    static func canCreateRoutine(existingCount: Int, tier: SubscriptionTier) -> Bool {
        _ = existingCount
        _ = tier
        return true
    }

    static func canCopyRoutineSource(
        existingCount: Int,
        sourceContainsSupersets: Bool,
        tier: SubscriptionTier
    ) -> Bool {
        _ = existingCount
        _ = sourceContainsSupersets
        _ = tier
        return true
    }
}

enum NutritionAccessPolicy {
    static let freeManualLogLimit = 3

    static func canLogManually(existingLogCount: Int, tier: SubscriptionTier) -> Bool {
        tier == .pro || existingLogCount < freeManualLogLimit
    }

    static func remainingFreeLogs(existingLogCount: Int, tier: SubscriptionTier) -> Int? {
        guard tier != .pro else { return nil }
        return max(0, freeManualLogLimit - existingLogCount)
    }

    static func canUseAdvancedEntry(_ feature: ProFeature, tier: SubscriptionTier) -> Bool {
        switch feature {
        case .calorieTracking:
            return true
        case .foodSearch, .barcodeScan, .aiDescribe, .foodPhoto, .labelScan, .nutritionBackup:
            return tier == .pro
        }
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
