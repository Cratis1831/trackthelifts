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
        Schema([FoodLog.self, CustomFood.self])
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

        static func + (lhs: Totals, rhs: Totals) -> Totals {
            Totals(
                calories: lhs.calories + rhs.calories,
                proteinGrams: lhs.proteinGrams + rhs.proteinGrams,
                carbsGrams: lhs.carbsGrams + rhs.carbsGrams,
                fatGrams: lhs.fatGrams + rhs.fatGrams
            )
        }
    }

    static func totals(from logs: [FoodLog]) -> Totals {
        logs.reduce(into: Totals()) { running, log in
            running.calories += log.calories
            running.proteinGrams += log.proteinGrams
            running.carbsGrams += log.carbsGrams
            running.fatGrams += log.fatGrams
        }
    }

    static func logs(on day: Date, from logs: [FoodLog], calendar: Calendar = .current) -> [FoodLog] {
        logs.filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
    }
}
