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
        exercise: Exercise, 
        workout: Workout,
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
        self.exercise = exercise
        self.workout = workout
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncDate = lastSyncDate
    }
}

