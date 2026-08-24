//
//  CloudSyncStoreMigrator.swift
//  TrackTheLifts
//

import Foundation
import SwiftData

/// Moves data between the local-only store and the CloudKit store via a JSON snapshot.
///
/// SwiftData cannot attach CloudKit to a store opened with `cloudKitDatabase: .none`
/// (`loadIssueModelContainer`). It also cannot open a CloudKit-backed container in a process
/// that already opened the same schema locally. Local and CloudKit therefore use **separate
/// store files**, and CloudKit is only opened on a cold launch that has not already opened
/// the local schema.
enum CloudSyncStoreMigrator {
    /// Named SwiftData configuration so the CloudKit store is never the default local `.store`.
    static let cloudStoreName = "TrackTheLiftsCloudKit"

    static func localConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration(schema: schema, cloudKitDatabase: .none)
    }

    static func cloudConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration(
            cloudStoreName,
            schema: schema,
            cloudKitDatabase: .private(CloudSyncPreference.containerIdentifier)
        )
    }

    static func storeExists(_ configuration: ModelConfiguration) -> Bool {
        FileManager.default.fileExists(atPath: configuration.url.path)
    }

    /// CloudKit may only be the first store opened for this schema in the process. If local
    /// data still needs to be snapshotted, this launch must open local, write the JSON, and
    /// wait for a force-quit.
    static func shouldOpenCloudKitStore(
        localStoreExists: Bool,
        cloudStoreExists: Bool,
        hasPendingImport: Bool
    ) -> Bool {
        if hasPendingImport { return true }
        if cloudStoreExists { return true }
        if !localStoreExists { return true }
        return false
    }

    static var snapshotURL: URL {
        applicationSupportDirectory.appendingPathComponent("pending-cloudkit-import.json")
    }

    static func hasPendingImport(at url: URL = snapshotURL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func writeSnapshot(from context: ModelContext, to url: URL = snapshotURL) throws {
        let snapshot = try CloudSyncSnapshot.capture(from: context)
        let data = try JSONEncoder.cloudSync.encode(snapshot)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    static func importPendingSnapshot(into context: ModelContext, from url: URL = snapshotURL) throws {
        guard hasPendingImport(at: url) else { return }
        let data = try Data(contentsOf: url)
        let snapshot = try JSONDecoder.cloudSync.decode(CloudSyncSnapshot.self, from: data)
        try snapshot.apply(to: context)
        try context.save()
        clearPendingSnapshot(at: url)
    }

    static func clearPendingSnapshot(at url: URL = snapshotURL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TrackTheLifts", isDirectory: true)
    }
}

private extension JSONEncoder {
    static let cloudSync: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let cloudSync: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private struct CloudSyncSnapshot: Codable {
    var bodyparts: [BodypartRecord]
    var exercises: [ExerciseRecord]
    var workouts: [WorkoutRecord]
    var exerciseSets: [ExerciseSetRecord]
    var templates: [TemplateRecord]
    var templateExercises: [TemplateExerciseRecord]

    static func capture(from context: ModelContext) throws -> CloudSyncSnapshot {
        let bodyparts = try context.fetch(FetchDescriptor<Bodypart>())
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let exerciseSets = try context.fetch(FetchDescriptor<ExerciseSet>())
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let templateExercises = try context.fetch(FetchDescriptor<WorkoutTemplateExercise>())

        return CloudSyncSnapshot(
            bodyparts: bodyparts.map(BodypartRecord.init),
            exercises: exercises.map(ExerciseRecord.init),
            workouts: workouts.map(WorkoutRecord.init),
            exerciseSets: exerciseSets.compactMap(ExerciseSetRecord.init),
            templates: templates.map(TemplateRecord.init),
            templateExercises: templateExercises.compactMap(TemplateExerciseRecord.init)
        )
    }

    func apply(to context: ModelContext) throws {
        var bodypartsByID = try indexed(Bodypart.self, id: \.id, in: context)
        var exercisesByID = try indexed(Exercise.self, id: \.id, in: context)
        var workoutsByID = try indexed(Workout.self, id: \.id, in: context)
        var templatesByID = try indexed(WorkoutTemplate.self, id: \.id, in: context)
        let existingSetIDs = try Set(context.fetch(FetchDescriptor<ExerciseSet>()).map(\.id))
        let existingTemplateExerciseIDs = try Set(
            context.fetch(FetchDescriptor<WorkoutTemplateExercise>()).map(\.id)
        )

        for record in bodyparts {
            if bodypartsByID[record.id] != nil { continue }
            let bodypart = Bodypart(
                id: record.id,
                name: record.name,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                isDeleted: record.isDeleted,
                cloudKitRecordID: record.cloudKitRecordID,
                lastSyncDate: record.lastSyncDate
            )
            context.insert(bodypart)
            bodypartsByID[record.id] = bodypart
        }

        for record in exercises {
            if exercisesByID[record.id] != nil { continue }
            let exercise = Exercise(
                id: record.id,
                name: record.name,
                bodypart: record.bodypartID.flatMap { bodypartsByID[$0] },
                category: ExerciseCategory(rawValue: record.categoryRawValue) ?? .other,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                isDeleted: record.isDeleted,
                cloudKitRecordID: record.cloudKitRecordID,
                lastSyncDate: record.lastSyncDate
            )
            context.insert(exercise)
            exercisesByID[record.id] = exercise
        }

        for record in workouts {
            if workoutsByID[record.id] != nil { continue }
            let workout = Workout(
                id: record.id,
                title: record.title,
                date: record.date,
                notes: record.notes,
                isActive: record.isActive,
                completedAt: record.completedAt,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                isDeleted: record.isDeleted,
                cloudKitRecordID: record.cloudKitRecordID,
                lastSyncDate: record.lastSyncDate
            )
            context.insert(workout)
            workoutsByID[record.id] = workout
        }

        for record in templates {
            if templatesByID[record.id] != nil { continue }
            let template = WorkoutTemplate(
                id: record.id,
                name: record.name,
                notes: record.notes,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                isDeleted: record.isDeleted,
                cloudKitRecordID: record.cloudKitRecordID,
                lastSyncDate: record.lastSyncDate
            )
            context.insert(template)
            templatesByID[record.id] = template
        }

        for record in exerciseSets {
            guard existingSetIDs.contains(record.id) == false else { continue }
            guard let exercise = exercisesByID[record.exerciseID],
                  let workout = workoutsByID[record.workoutID] else { continue }
            let set = ExerciseSet(
                id: record.id,
                weight: record.weight,
                reps: record.reps,
                order: record.order,
                exerciseOrder: record.exerciseOrder,
                exercise: exercise,
                workout: workout,
                isCompleted: record.isCompleted,
                setType: record.setType.flatMap(SetClassification.init(rawValue:)) ?? .working,
                exerciseNote: record.exerciseNote,
                intensityMetric: record.intensityMetricRaw.flatMap(IntensityMetric.init(rawValue:)),
                intensityValue: record.intensityValue,
                supersetGroupID: record.supersetGroupID,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                isDeleted: record.isDeleted,
                cloudKitRecordID: record.cloudKitRecordID,
                lastSyncDate: record.lastSyncDate
            )
            context.insert(set)
        }

        for record in templateExercises {
            guard existingTemplateExerciseIDs.contains(record.id) == false else { continue }
            guard let template = templatesByID[record.templateID],
                  let exercise = exercisesByID[record.exerciseID] else { continue }
            let templateExercise = WorkoutTemplateExercise(
                id: record.id,
                order: record.order,
                targetSets: record.targetSets,
                targetReps: record.targetReps,
                targetWeight: record.targetWeight,
                supersetGroupID: record.supersetGroupID,
                template: template,
                exercise: exercise,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                isDeleted: record.isDeleted,
                cloudKitRecordID: record.cloudKitRecordID,
                lastSyncDate: record.lastSyncDate
            )
            context.insert(templateExercise)
        }
    }

    private func indexed<T: PersistentModel>(
        _ type: T.Type,
        id: KeyPath<T, UUID>,
        in context: ModelContext
    ) throws -> [UUID: T] {
        var result: [UUID: T] = [:]
        for record in try context.fetch(FetchDescriptor<T>()) {
            result[record[keyPath: id]] = record
        }
        return result
    }
}

private struct BodypartRecord: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    init(_ bodypart: Bodypart) {
        id = bodypart.id
        name = bodypart.name
        createdAt = bodypart.createdAt
        updatedAt = bodypart.updatedAt
        isDeleted = bodypart.isDeleted
        cloudKitRecordID = bodypart.cloudKitRecordID
        lastSyncDate = bodypart.lastSyncDate
    }
}

private struct ExerciseRecord: Codable {
    var id: UUID
    var name: String
    var categoryRawValue: String
    var bodypartID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    init(_ exercise: Exercise) {
        id = exercise.id
        name = exercise.name
        categoryRawValue = exercise.categoryRawValue
        bodypartID = exercise.bodypart?.id
        createdAt = exercise.createdAt
        updatedAt = exercise.updatedAt
        isDeleted = exercise.isDeleted
        cloudKitRecordID = exercise.cloudKitRecordID
        lastSyncDate = exercise.lastSyncDate
    }
}

private struct WorkoutRecord: Codable {
    var id: UUID
    var title: String
    var date: Date
    var notes: String?
    var isActive: Bool
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    init(_ workout: Workout) {
        id = workout.id
        title = workout.title
        date = workout.date
        notes = workout.notes
        isActive = workout.isActive
        completedAt = workout.completedAt
        createdAt = workout.createdAt
        updatedAt = workout.updatedAt
        isDeleted = workout.isDeleted
        cloudKitRecordID = workout.cloudKitRecordID
        lastSyncDate = workout.lastSyncDate
    }
}

private struct ExerciseSetRecord: Codable {
    var id: UUID
    var weight: Double
    var reps: Int
    var order: Int
    var exerciseOrder: Int
    var isCompleted: Bool
    var setType: String?
    var exerciseNote: String?
    var intensityMetricRaw: String?
    var intensityValue: Double?
    var supersetGroupID: UUID?
    var exerciseID: UUID
    var workoutID: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    init?(_ set: ExerciseSet) {
        guard let exerciseID = set.exercise?.id, let workoutID = set.workout?.id else { return nil }
        id = set.id
        weight = set.weight
        reps = set.reps
        order = set.order
        exerciseOrder = set.exerciseOrder
        isCompleted = set.isCompleted
        setType = set.setType?.rawValue
        exerciseNote = set.exerciseNote
        intensityMetricRaw = set.intensityMetricRaw
        intensityValue = set.intensityValue
        supersetGroupID = set.supersetGroupID
        self.exerciseID = exerciseID
        self.workoutID = workoutID
        createdAt = set.createdAt
        updatedAt = set.updatedAt
        isDeleted = set.isDeleted
        cloudKitRecordID = set.cloudKitRecordID
        lastSyncDate = set.lastSyncDate
    }
}

private struct TemplateRecord: Codable {
    var id: UUID
    var name: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    init(_ template: WorkoutTemplate) {
        id = template.id
        name = template.name
        notes = template.notes
        createdAt = template.createdAt
        updatedAt = template.updatedAt
        isDeleted = template.isDeleted
        cloudKitRecordID = template.cloudKitRecordID
        lastSyncDate = template.lastSyncDate
    }
}

private struct TemplateExerciseRecord: Codable {
    var id: UUID
    var order: Int
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double
    var supersetGroupID: UUID?
    var templateID: UUID
    var exerciseID: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var cloudKitRecordID: String?
    var lastSyncDate: Date?

    init?(_ templateExercise: WorkoutTemplateExercise) {
        guard let templateID = templateExercise.template?.id,
              let exerciseID = templateExercise.exercise?.id else { return nil }
        id = templateExercise.id
        order = templateExercise.order
        targetSets = templateExercise.targetSets
        targetReps = templateExercise.targetReps
        targetWeight = templateExercise.targetWeight
        supersetGroupID = templateExercise.supersetGroupID
        self.templateID = templateID
        self.exerciseID = exerciseID
        createdAt = templateExercise.createdAt
        updatedAt = templateExercise.updatedAt
        isDeleted = templateExercise.isDeleted
        cloudKitRecordID = templateExercise.cloudKitRecordID
        lastSyncDate = templateExercise.lastSyncDate
    }
}
