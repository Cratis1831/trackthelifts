//
//  Double+Weight.swift
//  TrackTheLifts
//

import Foundation

extension Double {
    /// Whole numbers render without a decimal point (e.g. "135"); otherwise up to two decimals with
    /// trailing zeros trimmed, so quarter increments show cleanly (e.g. "137.25", "137.5").
    var formattedWeight: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(self))
        }
        var text = String(format: "%.2f", self)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
