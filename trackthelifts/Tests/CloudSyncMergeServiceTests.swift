import XCTest
import SwiftData
@testable import trackthelifts

final class CloudSyncMergeServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    func testMergesDuplicateExercisesAndRepointsHistory() throws {
        // The "local" copy is older, so it must win as the survivor.
        let localExercise = Exercise(name: "Bench Press", createdAt: Date(timeIntervalSince1970: 0))
        let syncedExercise = Exercise(name: "bench press", createdAt: Date(timeIntervalSince1970: 100))
        context.insert(localExercise)
        context.insert(syncedExercise)

        let workout = Workout(title: "Push Day", date: .now)
        context.insert(workout)
        let syncedSet = ExerciseSet(weight: 100, reps: 5, order: 0, exercise: syncedExercise, workout: workout)
        context.insert(syncedSet)

        let template = WorkoutTemplate(name: "Push Routine")
        context.insert(template)
        let templateExercise = WorkoutTemplateExercise(
            order: 0, targetSets: 3, targetReps: 8, targetWeight: 90,
            template: template, exercise: syncedExercise
        )
        context.insert(templateExercise)
        try context.save()

        CloudSyncMergeService.mergeDuplicates(in: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises.first?.id, localExercise.id)

        XCTAssertEqual(syncedSet.exercise?.id, localExercise.id, "The synced set must survive, repointed")
        XCTAssertEqual(templateExercise.exercise?.id, localExercise.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseSet>()).count, 1)
    }

    func testMergesDuplicateBodyparts() throws {
        let older = Bodypart(name: "Chest", createdAt: Date(timeIntervalSince1970: 0))
        let newer = Bodypart(name: "chest", createdAt: Date(timeIntervalSince1970: 100))
        context.insert(older)
        context.insert(newer)

        let exercise = Exercise(name: "Bench Press", bodypart: newer)
        context.insert(exercise)
        try context.save()

        CloudSyncMergeService.mergeDuplicates(in: context)

        let bodyparts = try context.fetch(FetchDescriptor<Bodypart>())
        XCTAssertEqual(bodyparts.count, 1)
        XCTAssertEqual(bodyparts.first?.id, older.id)
        XCTAssertEqual(exercise.bodypart?.id, older.id)
    }

    func testLeavesDistinctExercisesAndWorkoutsAlone() throws {
        let bench = Exercise(name: "Bench Press")
        let squat = Exercise(name: "Squat")
        context.insert(bench)
        context.insert(squat)

        let workoutA = Workout(title: "Day A", date: .now)
        let workoutB = Workout(title: "Day A", date: .now)
        context.insert(workoutA)
        context.insert(workoutB)
        try context.save()

        CloudSyncMergeService.mergeDuplicates(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 2)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<Workout>()).count, 2,
            "Same-titled workouts are distinct entries and must never be merged"
        )
    }

    func testMergesDuplicateStarterRoutinesAndLeavesCustomRoutines() throws {
        let catalogPush = WorkoutTemplate(
            id: PrebuiltRoutineCatalog.recipes.first { $0.name == "Push" }!.id,
            name: "Push",
            createdAt: Date(timeIntervalSince1970: 10),
            isPrebuilt: true
        )
        let syncedPush = WorkoutTemplate(
            name: "Push",
            createdAt: Date(timeIntervalSince1970: 0),
            isPrebuilt: true
        )
        let customPush = WorkoutTemplate(name: "Push", isPrebuilt: false)
        context.insert(catalogPush)
        context.insert(syncedPush)
        context.insert(customPush)
        try context.save()

        CloudSyncMergeService.mergeDuplicates(in: context)

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertEqual(templates.filter(\.isStarterRoutine).count, 1)
        XCTAssertEqual(templates.filter(\.isStarterRoutine).first?.id, catalogPush.id)
        XCTAssertEqual(templates.filter { !$0.isStarterRoutine }.count, 1)
    }

    func testIsIdempotent() throws {
        context.insert(Exercise(name: "Deadlift", createdAt: Date(timeIntervalSince1970: 0)))
        context.insert(Exercise(name: "Deadlift", createdAt: Date(timeIntervalSince1970: 50)))
        try context.save()

        CloudSyncMergeService.mergeDuplicates(in: context)
        CloudSyncMergeService.mergeDuplicates(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 1)
    }
}
