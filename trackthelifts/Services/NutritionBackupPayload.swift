//
//  NutritionBackupPayload.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

enum NutritionBackupCodec {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct NutritionSnapshotRequest: Encodable {
    var snapshot: NutritionBackupPayload
}

struct NutritionSnapshotResponse: Decodable {
    var snapshot: NutritionBackupPayload
}

struct NutritionBackupPayload: Codable, Equatable {
    static let schemaVersion = 1
    static let maxLogs = 20_000

    var schemaVersion: Int
    var clientRev: Int
    var updatedAt: Date
    var targets: NutritionBackupTargets
    var logs: [NutritionBackupLog]
    var customFoods: [NutritionBackupCustomFood]
    var savedMeals: [NutritionBackupSavedMeal]

    static func capture(
        logs: [FoodLog],
        customFoods: [CustomFood],
        savedMeals: [SavedMeal],
        targets: NutritionPreference,
        clientRev: Int,
        now: Date = .now
    ) -> NutritionBackupPayload {
        let newestLogs = logs
            .sorted { $0.loggedAt > $1.loggedAt }
            .prefix(maxLogs)
            .map(NutritionBackupLog.init(log:))
        return NutritionBackupPayload(
            schemaVersion: schemaVersion,
            clientRev: clientRev,
            updatedAt: now,
            targets: NutritionBackupTargets(preference: targets),
            logs: Array(newestLogs),
            customFoods: customFoods.map(NutritionBackupCustomFood.init(food:)),
            savedMeals: savedMeals.map(NutritionBackupSavedMeal.init(meal:))
        )
    }

    var isEmpty: Bool {
        logs.isEmpty && customFoods.isEmpty && savedMeals.isEmpty && !targets.hasSetTargets
    }
}

struct NutritionBackupTargets: Codable, Equatable {
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double

    init(
        calories: Double = 0,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double = 0
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
    }

    init(preference: NutritionPreference) {
        calories = preference.calories
        proteinGrams = preference.proteinGrams
        carbsGrams = preference.carbsGrams
        fatGrams = preference.fatGrams
        fiberGrams = preference.fiberGrams
    }

    var hasSetTargets: Bool { calories > 0 }

    func apply(to preference: NutritionPreference) {
        preference.calories = calories
        preference.proteinGrams = proteinGrams
        preference.carbsGrams = carbsGrams
        preference.fatGrams = fatGrams
        preference.fiberGrams = fiberGrams
    }
}

struct NutritionBackupLog: Codable, Equatable {
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

    init(log: FoodLog) {
        id = log.id
        loggedAt = log.loggedAt
        mealTypeRaw = log.mealTypeRaw
        sourceTypeRaw = log.sourceTypeRaw
        sourceFoodID = log.sourceFoodID
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
        isEstimated = log.isEstimated
        createdAt = log.createdAt
    }

    func makeLog() -> FoodLog {
        FoodLog(
            id: id,
            loggedAt: loggedAt,
            mealType: MealType(rawValue: mealTypeRaw) ?? .snack,
            sourceType: FoodSourceType(rawValue: sourceTypeRaw) ?? .manual,
            sourceFoodID: sourceFoodID,
            displayName: displayName,
            brand: brand,
            quantity: quantity,
            unit: unit,
            weightGrams: weightGrams,
            calories: calories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            sugarGrams: sugarGrams,
            sodiumMilligrams: sodiumMilligrams,
            isEstimated: isEstimated,
            createdAt: createdAt
        )
    }
}

struct NutritionBackupCustomFood: Codable, Equatable {
    var id: UUID
    var name: String
    var brand: String?
    var barcode: String?
    var servingDescription: String?
    var servingWeightGrams: Double?
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double?
    var sugarGrams: Double?
    var sodiumMilligrams: Double?
    var isFavorite: Bool
    var lastUsedAt: Date?
    var createdAt: Date

    init(food: CustomFood) {
        id = food.id
        name = food.name
        brand = food.brand
        barcode = food.barcode
        servingDescription = food.servingDescription
        servingWeightGrams = food.servingWeightGrams
        calories = food.calories
        proteinGrams = food.proteinGrams
        carbsGrams = food.carbsGrams
        fatGrams = food.fatGrams
        fiberGrams = food.fiberGrams
        sugarGrams = food.sugarGrams
        sodiumMilligrams = food.sodiumMilligrams
        isFavorite = food.isFavorite
        lastUsedAt = food.lastUsedAt
        createdAt = food.createdAt
    }

    func makeFood() -> CustomFood {
        CustomFood(
            id: id,
            name: name,
            brand: brand,
            barcode: barcode,
            servingDescription: servingDescription,
            servingWeightGrams: servingWeightGrams,
            calories: calories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            sugarGrams: sugarGrams,
            sodiumMilligrams: sodiumMilligrams,
            isFavorite: isFavorite,
            lastUsedAt: lastUsedAt,
            createdAt: createdAt
        )
    }
}

struct NutritionBackupSavedMeal: Codable, Equatable {
    var id: UUID
    var name: String
    var foods: [SavedMealFood]
    var lastUsedAt: Date
    var createdAt: Date

    init(meal: SavedMeal) {
        id = meal.id
        name = meal.name
        foods = meal.foods
        lastUsedAt = meal.lastUsedAt
        createdAt = meal.createdAt
    }

    func makeMeal() -> SavedMeal {
        SavedMeal(id: id, name: name, foods: foods, lastUsedAt: lastUsedAt, createdAt: createdAt)
    }
}
