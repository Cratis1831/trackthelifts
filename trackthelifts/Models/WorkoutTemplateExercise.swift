//
//  WorkoutTemplateExercise.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

@Model
class WorkoutTemplateExercise {
    var id: UUID
    var order: Int
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double

    // CloudKit sync properties
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    @Relationship var template: WorkoutTemplate
    @Relationship var exercise: Exercise

    init(
        id: UUID = UUID(),
        order: Int,
        targetSets: Int,
        targetReps: Int,
        targetWeight: Double,
        template: WorkoutTemplate,
        exercise: Exercise,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false,
        cloudKitRecordID: String? = nil,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.template = template
        self.exercise = exercise
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.cloudKitRecordID = cloudKitRecordID
        self.lastSyncDate = lastSyncDate
    }
}
