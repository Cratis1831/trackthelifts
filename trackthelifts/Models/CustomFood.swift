//
//  CustomFood.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

/// On-device custom/recent food. Private by default; never written to CloudKit.
@Model
final class CustomFood {
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

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        servingDescription: String? = "1 serving",
        servingWeightGrams: Double? = nil,
        calories: Double,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil,
        sugarGrams: Double? = nil,
        sodiumMilligrams: Double? = nil,
        isFavorite: Bool = false,
        lastUsedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.servingDescription = servingDescription
        self.servingWeightGrams = servingWeightGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMilligrams = sodiumMilligrams
        self.isFavorite = isFavorite
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }
}
