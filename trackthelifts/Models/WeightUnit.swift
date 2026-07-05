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
}
