import XCTest
import SwiftData
@testable import trackthelifts

@MainActor
final class CloudSyncStoreMigratorTests: XCTestCase {
    private var snapshotURL: URL!

    override func setUp() {
        super.setUp()
        snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-cloudkit-import-\(UUID().uuidString).json")
    }

    override func tearDown() {
        CloudSyncStoreMigrator.clearPendingSnapshot(at: snapshotURL)
        snapshotURL = nil
        super.tearDown()
    }

    func testShouldOpenCloudKitOnlyWhenSafeForThisProcess() {
        XCTAssertTrue(
            CloudSyncStoreMigrator.shouldOpenCloudKitStore(
                localStoreExists: true,
                cloudStoreExists: false,
                hasPendingImport: true
            ),
            "A pending JSON snapshot means this cold launch should open CloudKit first"
        )
        XCTAssertTrue(
            CloudSyncStoreMigrator.shouldOpenCloudKitStore(
                localStoreExists: true,
                cloudStoreExists: true,
                hasPendingImport: false
            ),
            "Once the CloudKit store exists, later launches open it first"
        )
        XCTAssertTrue(
            CloudSyncStoreMigrator.shouldOpenCloudKitStore(
                localStoreExists: false,
                cloudStoreExists: false,
                hasPendingImport: false
            ),
            "No local file means there is nothing to snapshot first"
        )
        XCTAssertFalse(
            CloudSyncStoreMigrator.shouldOpenCloudKitStore(
                localStoreExists: true,
                cloudStoreExists: false,
                hasPendingImport: false
            ),
            "Existing local data must be snapshotted this launch; CloudKit waits for a force-quit"
        )
    }

    func testSnapshotRoundTripsWorkoutsWithoutDiscardingHistory() throws {
        let source = try makeContainer()
        let sourceContext = source.mainContext

        let chest = Bodypart(name: "Chest")
        let bench = Exercise(name: "Bench Press", bodypart: chest, category: .barbell)
        sourceContext.insert(chest)
        sourceContext.insert(bench)

        let workout = Workout(title: "Push Day", date: Date(timeIntervalSince1970: 1_700_000_000), notes: "Felt strong")
        workout.isActive = false
        workout.completedAt = Date(timeIntervalSince1970: 1_700_000_600)
        workout.healthKitWorkoutUUID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        sourceContext.insert(workout)

        let set = ExerciseSet(
            weight: 225,
            reps: 5,
            order: 0,
            exerciseOrder: 0,
            exercise: bench,
            workout: workout,
            isCompleted: true,
            setType: .working,
            exerciseNote: "Pause at the bottom"
        )
        sourceContext.insert(set)

        let template = WorkoutTemplate(name: "Push Routine", notes: "Monday")
        sourceContext.insert(template)
        let templateExercise = WorkoutTemplateExercise(
            order: 0,
            targetSets: 3,
            targetReps: 5,
            targetWeight: 225,
            template: template,
            exercise: bench
        )
        sourceContext.insert(templateExercise)
        try sourceContext.save()

        try CloudSyncStoreMigrator.writeSnapshot(from: sourceContext, to: snapshotURL)
        XCTAssertTrue(CloudSyncStoreMigrator.hasPendingImport(at: snapshotURL))

        let destination = try makeContainer()
        try CloudSyncStoreMigrator.importPendingSnapshot(into: destination.mainContext, from: snapshotURL)
        XCTAssertFalse(CloudSyncStoreMigrator.hasPendingImport(at: snapshotURL))

        let importedWorkouts = try destination.mainContext.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(importedWorkouts.count, 1)
        XCTAssertEqual(importedWorkouts.first?.id, workout.id)
        XCTAssertEqual(importedWorkouts.first?.title, "Push Day")
        XCTAssertEqual(importedWorkouts.first?.notes, "Felt strong")
        XCTAssertEqual(importedWorkouts.first?.healthKitWorkoutUUID, workout.healthKitWorkoutUUID)

        let importedSets = try destination.mainContext.fetch(FetchDescriptor<ExerciseSet>())
        XCTAssertEqual(importedSets.count, 1)
        XCTAssertEqual(importedSets.first?.weight, 225)
        XCTAssertEqual(importedSets.first?.exercise?.id, bench.id)
        XCTAssertEqual(importedSets.first?.workout?.id, workout.id)
        XCTAssertEqual(importedSets.first?.exerciseNote, "Pause at the bottom")

        let importedTemplates = try destination.mainContext.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertEqual(importedTemplates.count, 1)
        XCTAssertEqual(importedTemplates.first?.id, template.id)

        let importedTemplateExercises = try destination.mainContext.fetch(FetchDescriptor<WorkoutTemplateExercise>())
        XCTAssertEqual(importedTemplateExercises.count, 1)
        XCTAssertEqual(importedTemplateExercises.first?.targetWeight, 225)
        XCTAssertEqual(importedTemplateExercises.first?.exercise?.id, bench.id)
    }

    func testImportIsIdempotentForExistingIDs() throws {
        let source = try makeContainer()
        let exercise = Exercise(name: "Squat", category: .barbell)
        source.mainContext.insert(exercise)
        try source.mainContext.save()

        try CloudSyncStoreMigrator.writeSnapshot(from: source.mainContext, to: snapshotURL)

        let destination = try makeContainer()
        try CloudSyncStoreMigrator.importPendingSnapshot(into: destination.mainContext, from: snapshotURL)

        try CloudSyncStoreMigrator.writeSnapshot(from: source.mainContext, to: snapshotURL)
        try CloudSyncStoreMigrator.importPendingSnapshot(into: destination.mainContext, from: snapshotURL)

        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<Exercise>()).count, 1)
    }

    func testRemoveStoreFilesDeletesStoreAndSidecarsOnly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloudkit-store-cleanup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = directory.appendingPathComponent("TrackTheLiftsCloudKit.store")
        let wal = directory.appendingPathComponent("TrackTheLiftsCloudKit.store-wal")
        let shm = directory.appendingPathComponent("TrackTheLiftsCloudKit.store-shm")
        let unrelated = directory.appendingPathComponent("default.store")
        for url in [store, wal, shm, unrelated] {
            try Data().write(to: url)
        }

        CloudSyncStoreMigrator.removeStoreFiles(at: store)

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: wal.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: shm.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    func testEmptySnapshotStillCreatesPendingImportFile() throws {
        let source = try makeContainer()
        try CloudSyncStoreMigrator.writeSnapshot(from: source.mainContext, to: snapshotURL)
        XCTAssertTrue(
            CloudSyncStoreMigrator.hasPendingImport(at: snapshotURL),
            "Even an empty snapshot must persist so the next cold launch opens CloudKit first"
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
        let configuration = ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
