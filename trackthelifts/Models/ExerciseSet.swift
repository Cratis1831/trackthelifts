//
//  ExerciseSet.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-05.
//

import Foundation
import SwiftData

@Model
class ExerciseSet {
    var id: UUID
    var weight: Double
    var reps: Int
    var order: Int
    /// Position of this set's exercise within the workout (shared by every set of that
    /// exercise), so exercises can be drag-reordered independently of when each set was logged.
    var exerciseOrder: Int = 0
    var isCompleted: Bool
    /// Warm-up / working / failure classification for this specific set. Defaults to `.working`
    /// so existing sets (and new sets that are never explicitly classified) behave as before.
    var setType: SetClassification = SetClassification.working

    // CloudKit sync properties
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    @Relationship var exercise: Exercise
    @Relationship var workout: Workout

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        order: Int,
        exerciseOrder: Int = 0,
        exercise: Exercise,
        workout: Workout,
        isCompleted: Bool = false,
        setType: SetClassification = .working,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false,
        cloudKitRecordID: String? = nil,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.order = order
        self.exerciseOrder = exerciseOrder
        self.exercise = exercise
        self.workout = workout
        self.isCompleted = isCompleted
        self.setType = setType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncDate = lastSyncDate
    }
}

