//
//  NutritionStore.swift
//  TrackTheLifts
//

import Foundation
import SwiftData
import SwiftUI

/// Local-only nutrition SwiftData store. Kept on a separate named configuration so food diary
/// records can never ride along with the CloudKit workout store (health-adjacent data).
enum NutritionStore {
    static let configurationName = "ForgeLyteNutrition"

    static var schema: Schema {
        Schema([FoodLog.self, CustomFood.self, SavedMeal.self])
    }

    static func makeContainer() -> ModelContainer {
        let schema = schema
        let configuration = ModelConfiguration(
            configurationName,
            schema: schema,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to open the local nutrition store: \(error)")
        }
    }
}

private struct NutritionContainerKey: EnvironmentKey {
    static let defaultValue: ModelContainer? = nil
}

extension EnvironmentValues {
    var nutritionContainer: ModelContainer? {
        get { self[NutritionContainerKey.self] }
        set { self[NutritionContainerKey.self] = newValue }
    }
}

enum NutritionMath {
    struct Totals: Equatable {
        var calories: Double = 0
        var proteinGrams: Double = 0
        var carbsGrams: Double = 0
        var fatGrams: Double = 0
        var fiberGrams: Double = 0

        static func + (lhs: Totals, rhs: Totals) -> Totals {
            Totals(
                calories: lhs.calories + rhs.calories,
                proteinGrams: lhs.proteinGrams + rhs.proteinGrams,
                carbsGrams: lhs.carbsGrams + rhs.carbsGrams,
                fatGrams: lhs.fatGrams + rhs.fatGrams,
                fiberGrams: lhs.fiberGrams + rhs.fiberGrams
            )
        }
    }

    static func totals(from logs: [FoodLog]) -> Totals {
        logs.reduce(into: Totals()) { running, log in
            running.calories += log.calories
            running.proteinGrams += log.proteinGrams
            running.carbsGrams += log.carbsGrams
            running.fatGrams += log.fatGrams
            running.fiberGrams += log.fiberGrams ?? 0
        }
    }

    static func logs(on day: Date, from logs: [FoodLog], calendar: Calendar = .current) -> [FoodLog] {
        logs.filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
    }
}

enum NutritionRounding {
    static func calories(_ value: Double) -> Double {
        rounded(value, scale: 0)
    }

    static func macro(_ value: Double) -> Double {
        rounded(value, scale: 0)
    }

    static func serving(_ value: Double) -> Double {
        rounded(value, scale: 5)
    }

    static func caloriesText(_ value: Double) -> String {
        String(Int(calories(value)))
    }

    static func macroText(_ value: Double) -> String {
        caloriesText(value)
    }

    static func servingText(_ value: Double) -> String {
        trimmed(serving(value), scale: 5)
    }

    static func macrosCaption(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double? = nil,
        estimated: Bool = false
    ) -> String {
        var parts = [
            "\(caloriesText(calories)) kcal",
            "P \(macroText(protein))",
            "C \(macroText(carbs))",
            "F \(macroText(fat))"
        ]
        if let fiber {
            parts.append("Fi \(macroText(fiber))")
        }
        if estimated {
            parts.append("Est.")
        }
        return parts.joined(separator: " · ")
    }

    static func rounded(_ value: Double, scale: Int) -> Double {
        let factor = pow(10.0, Double(scale))
        return (value * factor).rounded(.toNearestOrAwayFromZero) / factor
    }

    private static func trimmed(_ value: Double, scale: Int) -> String {
        if value == value.rounded(.toNearestOrAwayFromZero) {
            return String(Int(value.rounded(.toNearestOrAwayFromZero)))
        }
        var text = String(format: "%.\(scale)f", value)
        while text.contains("."), text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }
}

enum MacroEnergy {
    static let caloriesPerProteinGram = 4.0
    static let caloriesPerCarbGram = 4.0
    static let caloriesPerFatGram = 9.0

    static func calories(proteinGrams: Double, carbsGrams: Double, fatGrams: Double) -> Double {
        NutritionRounding.calories(
            proteinGrams * caloriesPerProteinGram
                + carbsGrams * caloriesPerCarbGram
                + fatGrams * caloriesPerFatGram
        )
    }

    static func grams(
        calories: Double,
        proteinPercent: Double,
        carbPercent: Double,
        fatPercent: Double
    ) -> (protein: Double, carbs: Double, fat: Double) {
        (
            NutritionRounding.macro(calories * proteinPercent / 100 / caloriesPerProteinGram),
            NutritionRounding.macro(calories * carbPercent / 100 / caloriesPerCarbGram),
            NutritionRounding.macro(calories * fatPercent / 100 / caloriesPerFatGram)
        )
    }

    /// Whole-gram macros from a calorie target and % split. Calories can land a few kcal
    /// off the target because protein/carb grams are 4 kcal and fat grams are 9 kcal.
    static func resolved(
        calories: Double,
        proteinPercent: Double,
        carbPercent: Double,
        fatPercent: Double
    ) -> (protein: Double, carbs: Double, fat: Double, calories: Double) {
        let grams = grams(
            calories: calories,
            proteinPercent: proteinPercent,
            carbPercent: carbPercent,
            fatPercent: fatPercent
        )
        return (
            grams.protein,
            grams.carbs,
            grams.fat,
            self.calories(proteinGrams: grams.protein, carbsGrams: grams.carbs, fatGrams: grams.fat)
        )
    }

    static func percents(
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double
    ) -> (protein: Double, carbs: Double, fat: Double) {
        let proteinCalories = proteinGrams * caloriesPerProteinGram
        let carbCalories = carbsGrams * caloriesPerCarbGram
        let fatCalories = fatGrams * caloriesPerFatGram
        let total = proteinCalories + carbCalories + fatCalories
        guard total > 0 else { return (40, 40, 20) }
        return (
            NutritionRounding.macro(proteinCalories / total * 100),
            NutritionRounding.macro(carbCalories / total * 100),
            NutritionRounding.macro(fatCalories / total * 100)
        )
    }
}
