import Foundation

enum IntensityPreferenceMode: String, CaseIterable, Identifiable {
    case none
    case rpe
    case rir

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .rpe: return "RPE"
        case .rir: return "RIR"
        }
    }

    var metric: IntensityMetric? {
        switch self {
        case .none: return nil
        case .rpe: return .rpe
        case .rir: return .rir
        }
    }
}

enum IntensityAccessPolicy {
    static func effectiveMode(
        selectedMode: IntensityPreferenceMode,
        hasProAccess: Bool
    ) -> IntensityPreferenceMode {
        hasProAccess ? selectedMode : .none
    }
}

@Observable
final class IntensityPreference {
    static let shared = IntensityPreference()

    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    var mode: IntensityPreferenceMode {
        didSet { userDefaults.set(mode.rawValue, forKey: "intensityPreference") }
    }

    private init() {
        let rawValue = userDefaults.string(forKey: "intensityPreference")
        mode = rawValue.flatMap(IntensityPreferenceMode.init(rawValue:)) ?? .none
    }
}
