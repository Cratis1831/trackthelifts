//
//  SavedMeal.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

/// A named meal saved on-device so it can be logged again without catalogue search.
@Model
final class SavedMeal {
    var id: UUID
    var name: String
    var foodsData: Data
    var lastUsedAt: Date
    var createdAt: Date

    var foods: [SavedMealFood] {
        get { (try? JSONDecoder().decode([SavedMealFood].self, from: foodsData)) ?? [] }
        set { foodsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(
        id: UUID = UUID(),
        name: String,
        foods: [SavedMealFood],
        lastUsedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.foodsData = (try? JSONEncoder().encode(foods)) ?? Data()
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }
}

struct SavedMealFood: Codable, Hashable {
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
    var sourceTypeRaw: String
    var sourceFoodID: String?
    var isEstimated: Bool

    init(log: FoodLog) {
        displayName = log.displayName
        brand = log.brand
        quantity = log.quantity
        unit = log.unit
        weightGrams = log.weightGrams
        calories = log.calories
        proteinGrams = log.proteinGrams
        carbsGrams = log.carbsGrams
        fatGrams = log.fatGrams
        fiberGrams = log.fiberGrams
        sugarGrams = log.sugarGrams
        sodiumMilligrams = log.sodiumMilligrams
        sourceTypeRaw = log.sourceTypeRaw
        sourceFoodID = log.sourceFoodID
        isEstimated = log.isEstimated
    }
}

enum MealCopying {
    static let lookbackDays = 5

    struct Source: Identifiable, Hashable {
        var day: Date
        var meal: MealType
        var calories: Double
        var itemCount: Int

        var id: String {
            "\(day.timeIntervalSince1970)-\(meal.rawValue)"
        }
    }

    static func sources(
        from logs: [FoodLog],
        relativeTo day: Date,
        excluding meal: MealType? = nil,
        calendar: Calendar = .current
    ) -> [Source] {
        let start = calendar.startOfDay(for: day)
        let window: [Date] = (0...lookbackDays).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: start)
        }

        var result: [Source] = []
        for candidate in window {
            for type in MealType.allCases {
                if calendar.isDate(candidate, inSameDayAs: start), type == meal {
                    continue
                }
                let items = logs.filter {
                    calendar.isDate($0.loggedAt, inSameDayAs: candidate) && $0.mealType == type
                }
                guard !items.isEmpty else { continue }
                result.append(
                    Source(
                        day: candidate,
                        meal: type,
                        calories: items.reduce(0) { $0 + $1.calories },
                        itemCount: items.count
                    )
                )
            }
        }
        return result
    }

    static func items(
        matching source: Source,
        in logs: [FoodLog],
        calendar: Calendar = .current
    ) -> [FoodLog] {
        logs.filter {
            calendar.isDate($0.loggedAt, inSameDayAs: source.day) && $0.mealType == source.meal
        }
    }

    static func copy(
        _ items: [FoodLog],
        to meal: MealType,
        on day: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [FoodLog] {
        let loggedAt: Date = {
            if calendar.isDate(day, inSameDayAs: now) {
                return now
            }
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        }()

        return items.map { item in
            FoodLog(
                loggedAt: loggedAt,
                mealType: meal,
                sourceType: item.sourceType,
                sourceFoodID: item.sourceFoodID,
                displayName: item.displayName,
                brand: item.brand,
                quantity: item.quantity,
                unit: item.unit,
                weightGrams: item.weightGrams,
                calories: item.calories,
                proteinGrams: item.proteinGrams,
                carbsGrams: item.carbsGrams,
                fatGrams: item.fatGrams,
                fiberGrams: item.fiberGrams,
                sugarGrams: item.sugarGrams,
                sodiumMilligrams: item.sodiumMilligrams,
                isEstimated: item.isEstimated
            )
        }
    }

    static func defaultSavedName(meal: MealType, items: [FoodLog]) -> String {
        let names = items.prefix(2).map { FoodNameFormatting.displayName($0.displayName) }
        if names.isEmpty { return meal.displayName }
        return "\(meal.displayName) · \(names.joined(separator: ", "))"
    }
}
