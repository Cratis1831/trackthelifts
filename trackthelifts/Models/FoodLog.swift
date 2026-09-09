//
//  FoodLog.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }
}

enum FoodSourceType: String, Codable, CaseIterable {
    case manual
    case custom
    case usda
    case openFoodFacts
    case aiEstimate
    case labelScan
    case userContribution

    var displayName: String {
        switch self {
        case .manual: return "Manual entry"
        case .custom: return "Your food"
        case .usda: return "USDA FoodData Central"
        case .openFoodFacts: return "Open Food Facts · ODbL"
        case .aiEstimate: return "AI estimate"
        case .labelScan: return "Nutrition Facts scan"
        case .userContribution: return "Community contribution"
        }
    }

    var isEstimated: Bool { self == .aiEstimate }
}

@Model
final class FoodLog {
    var id: UUID
    var loggedAt: Date
    var mealTypeRaw: String
    var sourceTypeRaw: String
    var sourceFoodID: String?
    var displayName: String
    var brand: String?
    var quantity: Double
    var unit: String
    var weightGrams: Double?
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double?
    var sugarGrams: Double?
    var sodiumMilligrams: Double?
    var isEstimated: Bool
    var createdAt: Date

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var sourceType: FoodSourceType {
        get { FoodSourceType(rawValue: sourceTypeRaw) ?? .manual }
        set { sourceTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        loggedAt: Date = .now,
        mealType: MealType,
        sourceType: FoodSourceType = .manual,
        sourceFoodID: String? = nil,
        displayName: String,
        brand: String? = nil,
        quantity: Double = 1,
        unit: String = "serving",
        weightGrams: Double? = nil,
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil,
        sugarGrams: Double? = nil,
        sodiumMilligrams: Double? = nil,
        isEstimated: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.mealTypeRaw = mealType.rawValue
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceFoodID = sourceFoodID
        self.displayName = displayName
        self.brand = brand
        self.quantity = quantity
        self.unit = unit
        self.weightGrams = weightGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMilligrams = sodiumMilligrams
        self.isEstimated = isEstimated || sourceType.isEstimated
        self.createdAt = createdAt
    }
}

enum FoodNameFormatting {
    /// Title-cases all-lowercase names (`chicken breast` → `Chicken Breast`).
    /// Mixed-case catalogue names (USDA, brands) are left as-is.
    static func displayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed == trimmed.lowercased() {
            return trimmed.localizedCapitalized
        }
        return trimmed
    }

    static func optionalDisplayName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let formatted = displayName(raw)
        return formatted.isEmpty ? nil : formatted
    }
}
