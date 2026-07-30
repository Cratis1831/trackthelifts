//
//  Exercise.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-05.
//

import Foundation
import SwiftData

enum ExerciseCategory: String, CaseIterable, Codable, Identifiable {
    case barbell
    case dumbbell
    case kettlebell
    case cable
    case machine
    case bodyweight
    case cardio
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .kettlebell: "Kettlebell"
        case .cable: "Cable"
        case .machine: "Machine"
        case .bodyweight: "Bodyweight"
        case .cardio: "Cardio"
        case .other: "Other"
        }
    }
}

// All attributes carry default values and every relationship has an inverse because
// CloudKit mirroring requires it — see CloudSyncPreference.
@Model
class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    /// Stored as a string so existing SwiftData stores can add the field with a safe default.
    var categoryRawValue: String = "other"

    // CloudKit sync properties
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isDeleted: Bool = false
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    @Relationship var bodypart: Bodypart?

    /// Inverse of `ExerciseSet.exercise`. Deleting an exercise nullifies its sets'
    /// reference rather than deleting logged history.
    @Relationship(deleteRule: .nullify, inverse: \ExerciseSet.exercise)
    var exerciseSets: [ExerciseSet] = []

    /// Inverse of `WorkoutTemplateExercise.exercise`.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutTemplateExercise.exercise)
    var templateExercises: [WorkoutTemplateExercise] = []

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(), 
        name: String,
        bodypart: Bodypart? = nil,
        category: ExerciseCategory = .other,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false,
        cloudKitRecordID: String? = nil,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.bodypart = bodypart
        self.categoryRawValue = category.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncDate = lastSyncDate
    }
}
