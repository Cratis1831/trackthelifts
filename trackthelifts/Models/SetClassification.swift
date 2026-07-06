//
//  SetClassification.swift
//  TrackTheLifts
//

import Foundation

/// How a single `ExerciseSet` counts toward the workout: a warm-up, a normal working set, or a
/// set taken to failure. Stored per-set, so it only ever affects that one set on that one
/// exercise, never sets elsewhere in the workout.
enum SetClassification: String, Codable, CaseIterable {
    case warmup
    case working
    case failure

    var label: String {
        switch self {
        case .warmup: return "Warm-up"
        case .working: return "Working Set"
        case .failure: return "Failure Set"
        }
    }

    /// Short letter shown on the set-number tile. `nil` for working sets so the common case
    /// stays visually uncluttered.
    var badgeText: String? {
        switch self {
        case .warmup: return "W"
        case .working: return nil
        case .failure: return "F"
        }
    }
}
