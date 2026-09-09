//
//  NutritionPreference.swift
//  TrackTheLifts
//

import Foundation

/// On-device calorie/macro targets. Not synced; not stored in iCloud.
@Observable
final class NutritionPreference {
    static let shared = NutritionPreference()

    @ObservationIgnored
    private let userDefaults: UserDefaults

    var calories: Double {
        didSet { userDefaults.set(calories, forKey: Keys.calories) }
    }

    var proteinGrams: Double {
        didSet { userDefaults.set(proteinGrams, forKey: Keys.protein) }
    }

    var carbsGrams: Double {
        didSet { userDefaults.set(carbsGrams, forKey: Keys.carbs) }
    }

    var fatGrams: Double {
        didSet { userDefaults.set(fatGrams, forKey: Keys.fat) }
    }

    var hasSetTargets: Bool {
        calories > 0
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        calories = userDefaults.double(forKey: Keys.calories)
        proteinGrams = userDefaults.double(forKey: Keys.protein)
        carbsGrams = userDefaults.double(forKey: Keys.carbs)
        fatGrams = userDefaults.double(forKey: Keys.fat)
    }

    func reset() {
        calories = 0
        proteinGrams = 0
        carbsGrams = 0
        fatGrams = 0
    }

    private enum Keys {
        static let calories = "nutritionTargetCalories"
        static let protein = "nutritionTargetProteinGrams"
        static let carbs = "nutritionTargetCarbsGrams"
        static let fat = "nutritionTargetFatGrams"
    }
}
