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
    case icloudSync
    case unlimitedRoutines
    case advancedProgress
    case effortTracking
    case supersets
    case accentThemes

    init(_ feature: ProFeature) {
        switch feature {
        case .icloudSync: self = .icloudSync
        case .unlimitedRoutines: self = .unlimitedRoutines
        case .advancedProgress: self = .advancedProgress
        case .effortTracking: self = .effortTracking
        case .supersets: self = .supersets
        case .accentThemes: self = .accentThemes
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
    case purchaseStarted(packageType: AnalyticsPackageType, isTrial: Bool)
    case purchaseCompleted(packageType: AnalyticsPackageType, isTrial: Bool)
    case purchaseCancelled(packageType: AnalyticsPackageType, isTrial: Bool)
    case purchaseFailed(packageType: AnalyticsPackageType, isTrial: Bool, reason: AnalyticsFailureReason)
    case purchasePending(packageType: AnalyticsPackageType, isTrial: Bool)
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
        case .purchaseStarted: return "Purchase.started"
        case .purchaseCompleted: return "Purchase.completed"
        case .purchaseCancelled: return "Purchase.cancelled"
        case .purchaseFailed: return "Purchase.failed"
        case .purchasePending: return "Purchase.pending"
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
        case let .purchaseStarted(packageType, isTrial),
             let .purchaseCompleted(packageType, isTrial),
             let .purchaseCancelled(packageType, isTrial),
             let .purchasePending(packageType, isTrial):
            return ["packageType": packageType.rawValue, "isTrial": isTrial.analyticsString]
        case let .purchaseFailed(packageType, isTrial, reason):
            return [
                "packageType": packageType.rawValue,
                "isTrial": isTrial.analyticsString,
                "reason": reason.rawValue,
            ]
        case .purchaseRestoreCompleted(let hasActiveEntitlement):
            return ["hasActiveEntitlement": hasActiveEntitlement.analyticsString]
        case .purchaseRestoreFailed(let reason):
            return ["reason": reason.rawValue]
        }
    }

    static let allowedParameterKeys: Set<String> = [
        "fromPage", "skipped", "source", "exerciseCount", "completedSetCount",
        "earnedPersonalRecord", "containsSuperset", "hadLoggedSets", "feature",
        "packageType", "isTrial", "reason", "hasActiveEntitlement",
    ]
}

enum AnalyticsService {
    static let appID = "F72CF485-7359-4189-B014-C879D154E4AD"

    static func initialize() {
        TelemetryDeck.initialize(config: .init(appID: appID))
    }

    static func track(_ event: AnalyticsEvent) {
        TelemetryDeck.signal(event.name, parameters: event.parameters)
    }
}

private extension Bool {
    var analyticsString: String { self ? "true" : "false" }
}
