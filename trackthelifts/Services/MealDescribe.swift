//
//  MealDescribe.swift
//  TrackTheLifts
//

import Foundation

/// On-device draft for Describe with AI. Kept until a successful parse or Clear.
enum AIDescribeDraft {
    static let key = "aiDescribeDraftText"

    static func load(from userDefaults: UserDefaults = .standard) -> String {
        userDefaults.string(forKey: key) ?? ""
    }

    static func save(_ text: String, to userDefaults: UserDefaults = .standard) {
        if text.isEmpty {
            userDefaults.removeObject(forKey: key)
        } else {
            userDefaults.set(text, forKey: key)
        }
    }

    static func clear(in userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: key)
    }
}

enum MealDescribe {
    static func confirmableItems(from response: MealDescribeResponse) -> [ConfirmableDescribedFood] {
        response.items
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(ConfirmableDescribedFood.init(item:))
    }

    static func draft(item: DescribedMealItem, match: RemoteFood?) -> FoodEntryDraft {
        let quantity = item.quantity > 0 ? item.quantity : 1
        guard let match else {
            return FoodEntryDraft(
                id: "ai:\(item.name)",
                name: FoodNameFormatting.displayName(item.name),
                brand: FoodNameFormatting.optionalDisplayName(item.brand),
                calories: 0,
                proteinGrams: 0,
                carbsGrams: 0,
                fatGrams: 0,
                fiberGrams: nil,
                sugarGrams: nil,
                sodiumMilligrams: nil,
                quantity: quantity,
                servingDescription: item.unit,
                servingWeightGrams: item.estimatedWeightGrams,
                barcode: nil,
                sourceType: .aiEstimate,
                sourceFoodID: nil,
                isEstimated: true
            )
        }

        let factor = scaleFactor(item: item, match: match)
        let basis = nutritionBasis(item: item, match: match)
        return FoodEntryDraft(
            id: match.id,
            name: FoodNameFormatting.displayName(item.name),
            brand: FoodNameFormatting.optionalDisplayName(match.brand) ?? FoodNameFormatting.optionalDisplayName(item.brand),
            calories: scaled(basis.calories, factor: factor, digits: 0) ?? 0,
            proteinGrams: scaled(basis.proteinGrams, factor: factor) ?? 0,
            carbsGrams: scaled(basis.carbsGrams, factor: factor) ?? 0,
            fatGrams: scaled(basis.fatGrams, factor: factor) ?? 0,
            fiberGrams: scaled(basis.fiberGrams, factor: factor),
            sugarGrams: scaled(basis.sugarGrams, factor: factor),
            sodiumMilligrams: scaled(basis.sodiumMilligrams, factor: factor, digits: 0),
            quantity: quantity,
            servingDescription: item.unit,
            servingWeightGrams: item.estimatedWeightGrams ?? match.serving.weightGrams.map { $0 * factor },
            barcode: match.barcode,
            sourceType: .aiEstimate,
            sourceFoodID: match.source.externalID ?? match.id,
            isEstimated: true
        )
    }

    static func scaleFactor(item: DescribedMealItem, match: RemoteFood) -> Double {
        scaleFactor(item: item, serving: match.serving, hasPer100g: match.nutritionPer100g?.calories != nil)
    }

    static func scaleFactor(
        item: DescribedMealItem,
        serving: RemoteFood.Serving,
        hasPer100g: Bool = false
    ) -> Double {
        if let grams = gramPortion(item), grams > 0 {
            if hasPer100g {
                return grams / 100
            }
            if let servingGrams = serving.weightGrams, servingGrams > 0 {
                return grams / servingGrams
            }
            // Catalogue nutrition is per 100g when serving weight is missing.
            return grams / 100
        }
        if let servingAmount = serving.amount, servingAmount > 0 {
            return max(item.quantity, 0) / servingAmount
        }
        return max(item.quantity, 1)
    }

    static func gramPortion(_ item: DescribedMealItem) -> Double? {
        if let grams = item.estimatedWeightGrams, grams > 0 {
            return grams
        }
        let unit = item.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["g", "gram", "grams"].contains(unit), item.quantity > 0 {
            return item.quantity
        }
        return nil
    }

    static func portionLabel(_ item: DescribedMealItem) -> String {
        var label = "\(NutritionRounding.servingText(item.quantity)) \(item.unit)"
        if let grams = item.estimatedWeightGrams, grams > 0 {
            label += " · \(NutritionRounding.servingText(grams)) g"
        }
        return label
    }

    static func formatted(_ value: Double) -> String {
        NutritionRounding.macroText(value)
    }

    private static func nutritionBasis(item: DescribedMealItem, match: RemoteFood) -> RemoteFood.Nutrition {
        if gramPortion(item) != nil, let per100g = match.nutritionPer100g {
            return per100g
        }
        return match.nutrition
    }

    private static func scaled(_ value: Double?, factor: Double, digits: Int = 1) -> Double? {
        guard let value else { return nil }
        let scale = pow(10.0, Double(digits))
        return (value * factor * scale).rounded() / scale
    }
}

struct ConfirmableDescribedFood: Identifiable {
    let id: UUID
    var included: Bool
    let parsed: DescribedMealItem
    var selectedMatchID: String?
    var draft: FoodEntryDraft
    var nutritionConfirmed: Bool

    var matches: [RemoteFood] { parsed.matches }

    var selectedMatch: RemoteFood? {
        matches.first { $0.id == selectedMatchID }
    }

    var hasUsableNutrition: Bool {
        selectedMatch != nil || nutritionConfirmed || draft.calories > 0
    }

    var confidenceLabel: String {
        switch parsed.confidence.lowercased() {
        case "high": return "Higher confidence"
        case "medium": return "Medium confidence"
        default: return "Low confidence"
        }
    }

    init(item: DescribedMealItem) {
        let match = item.matches.first
        id = UUID()
        included = true
        parsed = item
        selectedMatchID = match?.id
        draft = MealDescribe.draft(item: item, match: match)
        nutritionConfirmed = false
    }

    mutating func selectMatch(id: String?) {
        selectedMatchID = id
        draft = MealDescribe.draft(item: parsed, match: matches.first { $0.id == id })
        nutritionConfirmed = id == nil ? nutritionConfirmed : false
    }

    mutating func applyEditedDraft(_ edited: FoodEntryDraft) {
        var next = edited
        next.sourceType = .aiEstimate
        next.isEstimated = true
        draft = next
        nutritionConfirmed = true
    }
}
