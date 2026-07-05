//
//  WeightUnitPreference.swift
//  TrackTheLifts
//

import Foundation

/// The app-wide weight unit (lbs/kg) the user has chosen, persisted across launches.
@Observable
class WeightUnitPreference {
    static let shared = WeightUnitPreference()

    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    var unit: WeightUnit {
        didSet {
            userDefaults.set(unit.rawValue, forKey: "weightUnit")
        }
    }

    private init() {
        if let raw = userDefaults.string(forKey: "weightUnit"), let saved = WeightUnit(rawValue: raw) {
            self.unit = saved
        } else {
            self.unit = .pounds
        }
    }
}
