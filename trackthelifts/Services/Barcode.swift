//
//  Barcode.swift
//  TrackTheLifts
//

import Foundation

enum Barcode {
    static func normalize(_ value: String) -> String {
        value.filter(\.isNumber)
    }

    static func matches(_ left: String?, _ right: String?) -> Bool {
        let a = significantDigits(normalize(left ?? ""))
        let b = significantDigits(normalize(right ?? ""))
        return !a.isEmpty && a == b
    }

    private static func significantDigits(_ value: String) -> String {
        let stripped = value.drop { $0 == "0" }
        if !stripped.isEmpty { return String(stripped) }
        return value.isEmpty ? "" : "0"
    }
}

extension FoodEntryDraft {
    static func manualBarcode(_ code: String) -> FoodEntryDraft {
        FoodEntryDraft(
            id: "barcode:\(code)",
            name: "",
            brand: nil,
            calories: 0,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0,
            fiberGrams: nil,
            sugarGrams: nil,
            sodiumMilligrams: nil,
            quantity: 1,
            servingDescription: "1 serving",
            servingWeightGrams: nil,
            barcode: code,
            sourceType: .manual,
            sourceFoodID: code,
            isEstimated: false
        )
    }
}
