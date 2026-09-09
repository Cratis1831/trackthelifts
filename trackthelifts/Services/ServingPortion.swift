//
//  ServingPortion.swift
//  TrackTheLifts
//

import Foundation

enum FoodServingUnit: String, CaseIterable, Identifiable {
    case serving
    case gram
    case ounce
    case pound
    case kilogram

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .serving: return "serving"
        case .gram: return "g"
        case .ounce: return "oz"
        case .pound: return "lb"
        case .kilogram: return "kg"
        }
    }

    var storageLabel: String {
        switch self {
        case .serving: return "serving"
        case .gram: return "g"
        case .ounce: return "oz"
        case .pound: return "lb"
        case .kilogram: return "kg"
        }
    }

    static func parse(_ raw: String?) -> FoodServingUnit {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value == "g" || value == "gram" || value == "grams" {
            return .gram
        }
        if value == "oz" || value.contains("ounce") {
            return .ounce
        }
        if value == "lb" || value.contains("pound") {
            return .pound
        }
        if value == "kg" || value.contains("kilogram") {
            return .kilogram
        }
        return .serving
    }
}

enum ServingPortionMath {
    static let gramsPerOunce = 28.349523125
    static let gramsPerPound = 453.59237

    /// Catalogue rows often say `100 g` (or `1 bar (60 g)`) without a numeric `weight_g`.
    /// Use any explicit grams first, then parse the serving label.
    static func inferredGramsPerServing(weightGrams: Double?, servingText: String?) -> Double? {
        if let weightGrams, weightGrams > 0 {
            return weightGrams
        }
        return grams(fromServingText: servingText)
    }

    static func grams(fromServingText text: String?) -> Double? {
        let compact = (text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !compact.isEmpty else { return nil }

        if let paren = firstWeight(in: compact, pattern: #"\((\d+(?:\.\d+)?)\s*(g|grams?|ml)\b"#) {
            return paren
        }
        if let grams = firstWeight(in: compact, pattern: #"(\d+(?:\.\d+)?)\s*(g|grams?|ml)\b"#) {
            return grams
        }
        if let oz = firstWeight(in: compact, pattern: #"\((\d+(?:\.\d+)?)\s*(oz|ounces?)\b"#) {
            return oz * gramsPerOunce
        }
        if let oz = firstWeight(in: compact, pattern: #"(\d+(?:\.\d+)?)\s*(oz|ounces?)\b"#) {
            return oz * gramsPerOunce
        }
        if let kg = firstWeight(in: compact, pattern: #"(\d+(?:\.\d+)?)\s*(kg|kilograms?)\b"#) {
            return kg * 1000
        }
        if let lb = firstWeight(in: compact, pattern: #"(\d+(?:\.\d+)?)\s*(lb|lbs|pounds?)\b"#) {
            return lb * gramsPerPound
        }
        return nil
    }

    static func grams(
        amount: Double,
        unit: FoodServingUnit,
        gramsPerServing: Double?
    ) -> Double? {
        guard amount >= 0 else { return nil }
        switch unit {
        case .gram:
            return amount
        case .ounce:
            return amount * gramsPerOunce
        case .pound:
            return amount * gramsPerPound
        case .kilogram:
            return amount * 1000
        case .serving:
            guard let gramsPerServing, gramsPerServing > 0 else { return nil }
            return amount * gramsPerServing
        }
    }

    static func amount(
        grams: Double,
        unit: FoodServingUnit,
        gramsPerServing: Double?
    ) -> Double? {
        guard grams >= 0 else { return nil }
        switch unit {
        case .gram:
            return grams
        case .ounce:
            return grams / gramsPerOunce
        case .pound:
            return grams / gramsPerPound
        case .kilogram:
            return grams / 1000
        case .serving:
            guard let gramsPerServing, gramsPerServing > 0 else { return nil }
            return grams / gramsPerServing
        }
    }

    static func factor(
        referenceAmount: Double,
        referenceUnit: FoodServingUnit,
        amount: Double,
        unit: FoodServingUnit,
        gramsPerServing: Double?
    ) -> Double {
        let referenceGrams = grams(
            amount: referenceAmount,
            unit: referenceUnit,
            gramsPerServing: gramsPerServing
        )
        let nextGrams = grams(amount: amount, unit: unit, gramsPerServing: gramsPerServing)
        if let referenceGrams, let nextGrams, referenceGrams > 0 {
            return nextGrams / referenceGrams
        }

        let referenceServings = servingCount(
            amount: referenceAmount,
            unit: referenceUnit,
            gramsPerServing: gramsPerServing
        )
        let nextServings = servingCount(
            amount: amount,
            unit: unit,
            gramsPerServing: gramsPerServing
        )
        guard referenceServings > 0 else { return 1 }
        return nextServings / referenceServings
    }

    static func formattedAmount(_ value: Double) -> String {
        NutritionRounding.servingText(value)
    }

    private static func servingCount(
        amount: Double,
        unit: FoodServingUnit,
        gramsPerServing: Double?
    ) -> Double {
        switch unit {
        case .serving:
            return amount
        case .gram, .ounce, .pound, .kilogram:
            guard
                let gramsPerServing,
                gramsPerServing > 0,
                let grams = grams(amount: amount, unit: unit, gramsPerServing: gramsPerServing)
            else { return amount }
            return grams / gramsPerServing
        }
    }

    private static func firstWeight(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > 1,
            let amountRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return Double(text[amountRange])
    }
}
