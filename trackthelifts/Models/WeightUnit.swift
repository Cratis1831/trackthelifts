//
//  WeightUnit.swift
//  TrackTheLifts
//

import Foundation

enum WeightUnit: String, CaseIterable {
    case pounds = "lbs"
    case kilograms = "kg"

    var label: String { rawValue }

    private static let poundsPerKilogram = 2.20462

    /// Converts a raw stored weight value from this unit into `target`.
    func convert(_ value: Double, to target: WeightUnit) -> Double {
        guard self != target else { return value }
        switch (self, target) {
        case (.pounds, .kilograms):
            return value / Self.poundsPerKilogram
        case (.kilograms, .pounds):
            return value * Self.poundsPerKilogram
        default:
            return value
        }
    }

    /// Converts and snaps the result to a sensible granularity for the target unit, so a bulk
    /// unit change doesn't leave awkward decimals: pounds land on whole numbers or 0.5 increments,
    /// kilograms are left as the raw converted value.
    func convertForStorage(_ value: Double, to target: WeightUnit) -> Double {
        let converted = convert(value, to: target)
        switch target {
        case .pounds:
            return (converted * 2).rounded() / 2
        case .kilograms:
            return converted
        }
    }
}
