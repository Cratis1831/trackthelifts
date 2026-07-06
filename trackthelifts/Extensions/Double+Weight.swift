//
//  Double+Weight.swift
//  TrackTheLifts
//

import Foundation

extension Double {
    /// Whole numbers render without a decimal point (e.g. "135"); otherwise one decimal place
    /// (e.g. "137.5").
    var formattedWeight: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
}
