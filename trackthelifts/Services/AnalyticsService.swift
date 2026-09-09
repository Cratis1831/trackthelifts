import Foundation
import TelemetryDeck

enum OnboardingAnalyticsPage: String, CaseIterable {
    case welcome
    case workouts
    case routines
    case progress
    case personalization
    case ready
    case profile
    case trial
}

enum WorkoutAnalyticsSource: String {
    case blank
    case routine
    case repeatWorkout = "repeat"
}

enum RoutineAnalyticsSource: String {
    case blank
    case pastWorkout
    case duplicate
    case edit
}

enum AnalyticsPackageType: String {
    case weekly
    case monthly
    case annual
    case lifetime
    case other

    static func fromRevenueCatDescription(_ description: String) -> Self {
        switch description.lowercased() {
        case "weekly": return .weekly
        case "monthly": return .monthly
        case "annual", "yearly": return .annual
        case "lifetime": return .lifetime
        default: return .other
        }
    }

    /// ActivationPal funnel plan names. Annual is `yearly` to match the dashboard docs.
    var activationPalPlan: String {
        self == .annual ? "yearly" : rawValue
    }
}

enum AnalyticsFailureReason: String {
    case notConfigured
    case sdkError
    case unknown

    static func fromSDKDescription(_ description: String) -> Self {
        Self(rawValue: description) ?? .unknown
    }
}

enum AnalyticsProFeature: String, CaseIterable {
    case calorieTracking
    case foodSearch
    case barcodeScan
    case aiDescribe
    case foodPhoto
    case labelScan
    case nutritionBackup

    init(_ feature: ProFeature) {
        switch feature {
        case .calorieTracking: self = .calorieTracking
        case .foodSearch: self = .foodSearch
        case .barcodeScan: self = .barcodeScan
        case .aiDescribe: self = .aiDescribe
        case .foodPhoto: self = .foodPhoto
        case .labelScan: self = .labelScan
        case .nutritionBackup: self = .nutritionBackup
        }
    }

    var activationPalPlacement: String {
        switch self {
        case .calorieTracking: return "calorie_tracking"
        case .foodSearch: return "food_search"
        case .barcodeScan: return "barcode_scan"
        case .aiDescribe: return "ai_describe"
        case .foodPhoto: return "food_photo"
        case .labelScan: return "label_scan"
        case .nutritionBackup: return "nutrition_backup"
        }
    }
}

enum AnalyticsEvent {
    case onboardingSkipped(fromPage: OnboardingAnalyticsPage)
    case onboardingCompleted(skipped: Bool)
    case workoutStarted(source: WorkoutAnalyticsSource)
    case workoutCompleted(
        exerciseCount: Int,
        completedSetCount: Int,
        earnedPersonalRecord: Bool,
        containsSuperset: Bool
    )
    case workoutCancelled(hadLoggedSets: Bool)
    case routineSaved(source: RoutineAnalyticsSource)
    case paywallShown(feature: AnalyticsProFeature)
    case purchaseCompleted(packageType: AnalyticsPackageType)
    case purchaseCancelled(packageType: AnalyticsPackageType)
    case purchaseFailed(packageType: AnalyticsPackageType, reason: AnalyticsFailureReason)
    case purchaseRestoreCompleted(hasActiveEntitlement: Bool)
    case purchaseRestoreFailed(reason: AnalyticsFailureReason)

    var name: String {
        switch self {
        case .onboardingSkipped: return "Onboarding.skipped"
        case .onboardingCompleted: return "Onboarding.completed"
        case .workoutStarted: return "Workout.started"
        case .workoutCompleted: return "Workout.completed"
        case .workoutCancelled: return "Workout.cancelled"
        case .routineSaved: return "Routine.saved"
        case .paywallShown: return "Paywall.shown"
        case .purchaseCompleted: return "Purchase.completed"
        case .purchaseCancelled: return "Purchase.cancelled"
        case .purchaseFailed: return "Purchase.failed"
        case .purchaseRestoreCompleted: return "Purchase.restoreCompleted"
        case .purchaseRestoreFailed: return "Purchase.restoreFailed"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .onboardingSkipped(let fromPage):
            return ["fromPage": fromPage.rawValue]
        case .onboardingCompleted(let skipped):
            return ["skipped": skipped.analyticsString]
        case .workoutStarted(let source):
            return ["source": source.rawValue]
        case let .workoutCompleted(exerciseCount, completedSetCount, earnedPersonalRecord, containsSuperset):
            return [
                "exerciseCount": String(exerciseCount),
                "completedSetCount": String(completedSetCount),
                "earnedPersonalRecord": earnedPersonalRecord.analyticsString,
                "containsSuperset": containsSuperset.analyticsString,
            ]
        case .workoutCancelled(let hadLoggedSets):
            return ["hadLoggedSets": hadLoggedSets.analyticsString]
        case .routineSaved(let source):
            return ["source": source.rawValue]
        case .paywallShown(let feature):
            return ["feature": feature.rawValue]
        case .purchaseCompleted(let packageType), .purchaseCancelled(let packageType):
            return ["packageType": packageType.rawValue]
        case .purchaseFailed(let packageType, let reason):
            return ["packageType": packageType.rawValue, "reason": reason.rawValue]
        case .purchaseRestoreCompleted(let hasActiveEntitlement):
            return ["hasActiveEntitlement": hasActiveEntitlement.analyticsString]
        case .purchaseRestoreFailed(let reason):
            return ["reason": reason.rawValue]
        }
    }

    static let allowedParameterKeys: Set<String> = [
        "fromPage", "skipped", "source", "exerciseCount", "completedSetCount",
        "earnedPersonalRecord", "containsSuperset", "hadLoggedSets", "feature",
        "packageType", "reason", "hasActiveEntitlement",
    ]
}

enum AnalyticsService {
    static let appID = "F72CF485-7359-4189-B014-C879D154E4AD"
    static let activationPalApp = "forgelyteliftworkouttracker"
    static let activationPalKey = "ap_pk_eb3952afce9ed1f4bbac1d80d47fcd041ba023b20db2eb06"

    static func initialize() {
        TelemetryDeck.initialize(config: .init(appID: appID))
    }

    static func configureActivationPal(userId: String?) {
        ActivationPal.configure(app: activationPalApp, key: activationPalKey, userId: userId)
    }

    static func track(_ event: AnalyticsEvent) {
        TelemetryDeck.signal(event.name, parameters: event.parameters)
        event.sendToActivationPal()
    }
}

private extension Bool {
    var analyticsString: String { self ? "true" : "false" }
}

private extension AnalyticsEvent {
    func sendToActivationPal() {
        switch self {
        case .onboardingSkipped:
            break
        case .onboardingCompleted:
            ActivationPal.onboardingCompleted()
        case .workoutStarted(let source):
            ActivationPal.track("workout_started", ["source": source.rawValue])
        case let .workoutCompleted(exerciseCount, completedSetCount, earnedPersonalRecord, containsSuperset):
            ActivationPal.track("workout_completed", [
                "exercise_count": exerciseCount,
                "completed_set_count": completedSetCount,
                "earned_personal_record": earnedPersonalRecord,
                "contains_superset": containsSuperset,
            ])
        case .workoutCancelled(let hadLoggedSets):
            ActivationPal.track("workout_cancelled", ["had_logged_sets": hadLoggedSets])
        case .routineSaved(let source):
            ActivationPal.track("routine_saved", ["source": source.rawValue])
        case .paywallShown:
            break
        case .purchaseCompleted(let packageType):
            ActivationPal.paywallPurchased(packageType.activationPalPlan)
        case .purchaseCancelled, .purchaseFailed, .purchaseRestoreCompleted, .purchaseRestoreFailed:
            break
        }
    }
}
