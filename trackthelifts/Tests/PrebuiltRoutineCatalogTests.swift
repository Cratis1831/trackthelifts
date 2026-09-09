import SwiftData
import XCTest
@testable import trackthelifts

final class PrebuiltRoutineCatalogTests: XCTestCase {
    func testRecipesUseDistinctStableIDsAndLibraryExercises() {
        let ids = PrebuiltRoutineCatalog.recipes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(Set(PrebuiltRoutineCatalog.recipes.map(\.name)).count, ids.count)

        let libraryNames = Set(ExerciseData.defaultExercises.map {
            ExerciseData.normalizedName($0.name)
        })
        for recipe in PrebuiltRoutineCatalog.recipes {
            XCTAssertFalse(recipe.exercises.isEmpty, "\(recipe.name) should include exercises")
            for target in recipe.exercises {
                XCTAssertTrue(
                    libraryNames.contains(ExerciseData.normalizedName(target.name)),
                    "\(recipe.name) references unknown exercise \(target.name)"
                )
                XCTAssertGreaterThan(target.sets, 0)
                XCTAssertGreaterThan(target.reps, 0)
            }
        }
    }

    func testStarterRoutinesDoNotCountAsCustomRoutines() {
        XCTAssertEqual(
            SubscriptionAccessPolicy.userCreatedRoutineCount(from: []),
            0
        )
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 0, tier: .free))
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 3, tier: .free))
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 30, tier: .free))
    }
}

@MainActor
final class PrebuiltRoutineSeedTests: XCTestCase {
    private var preferences: UserDefaults!
    private var preferencesSuiteName: String!

    override func setUp() {
        super.setUp()
        preferencesSuiteName = "PrebuiltRoutineSeedTests.\(UUID().uuidString)"
        preferences = UserDefaults(suiteName: preferencesSuiteName)
    }

    override func tearDown() {
        preferences.removePersistentDomain(forName: preferencesSuiteName)
        preferences = nil
        preferencesSuiteName = nil
        super.tearDown()
    }

    func testFreshStoreReceivesStarterRoutinesThatDoNotCountAsCustom() throws {
        let container = try makeContainer()
        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)
        PrebuiltRoutineCatalog.seedIfNeeded(in: container.mainContext, preferences: preferences)

        let templates = try container.mainContext.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertEqual(templates.count, PrebuiltRoutineCatalog.recipes.count)
        XCTAssertTrue(templates.allSatisfy(\.isStarterRoutine))
        XCTAssertEqual(SubscriptionAccessPolicy.userCreatedRoutineCount(from: templates), 0)
        XCTAssertTrue(
            SubscriptionAccessPolicy.canCreateRoutine(
                existingCount: SubscriptionAccessPolicy.userCreatedRoutineCount(from: templates),
                tier: .free
            )
        )
        XCTAssertEqual(
            preferences.integer(forKey: PrebuiltRoutineCatalog.catalogVersionKey),
            PrebuiltRoutineCatalog.catalogVersion
        )
    }

    func testSeedDoesNotRestoreADeletedStarterRoutine() throws {
        let container = try makeContainer()
        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)
        PrebuiltRoutineCatalog.seedIfNeeded(in: container.mainContext, preferences: preferences)

        let templates = try container.mainContext.fetch(FetchDescriptor<WorkoutTemplate>())
        container.mainContext.delete(templates[0])
        try container.mainContext.save()

        PrebuiltRoutineCatalog.seedIfNeeded(in: container.mainContext, preferences: preferences)

        XCTAssertEqual(
            try container.mainContext.fetchCount(FetchDescriptor<WorkoutTemplate>()),
            PrebuiltRoutineCatalog.recipes.count - 1
        )
    }

    func testDuplicatingAStarterCreatesACustomRoutine() throws {
        let container = try makeContainer()
        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)
        PrebuiltRoutineCatalog.seedIfNeeded(in: container.mainContext, preferences: preferences)

        let starter = try container.mainContext.fetch(FetchDescriptor<WorkoutTemplate>()).first
        let copy = try XCTUnwrap(starter).duplicateTemplate(in: container.mainContext)

        XCTAssertFalse(copy.isStarterRoutine)
        XCTAssertEqual(
            SubscriptionAccessPolicy.userCreatedRoutineCount(
                from: try container.mainContext.fetch(FetchDescriptor<WorkoutTemplate>())
            ),
            1
        )
    }

    func testSeedCollapsesDuplicateStarterRoutinesAndKeepsCustomCopies() throws {
        let container = try makeContainer()
        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)
        PrebuiltRoutineCatalog.seedIfNeeded(in: container.mainContext, preferences: preferences)

        let pushID = PrebuiltRoutineCatalog.recipes.first { $0.name == "Push" }!.id
        let duplicate = WorkoutTemplate(
            name: "Push",
            createdAt: Date(timeIntervalSince1970: 50),
            isPrebuilt: true
        )
        container.mainContext.insert(duplicate)
        let customPush = WorkoutTemplate(name: "Push", isPrebuilt: false)
        container.mainContext.insert(customPush)
        try container.mainContext.save()

        PrebuiltRoutineCatalog.seedIfNeeded(in: container.mainContext, preferences: preferences)

        let templates = try container.mainContext.fetch(FetchDescriptor<WorkoutTemplate>())
        let starterPush = templates.filter { $0.isStarterRoutine && $0.name == "Push" }
        XCTAssertEqual(starterPush.count, 1)
        XCTAssertEqual(starterPush.first?.id, pushID)
        XCTAssertEqual(templates.filter { !$0.isStarterRoutine && $0.name == "Push" }.count, 1)
        XCTAssertEqual(templates.filter(\.isStarterRoutine).count, PrebuiltRoutineCatalog.recipes.count)
    }

    func testSeedDoesNotAddASecondStarterWhenOneAlreadyExistsUnderAnotherID() throws {
        let container = try makeContainer()
        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)

        let existingPush = WorkoutTemplate(
            name: "Push",
            createdAt: Date(timeIntervalSince1970: 0),
            isPrebuilt: true
        )
        container.mainContext.insert(existingPush)
        try container.mainContext.save()

        PrebuiltRoutineCatalog.seedIfNeeded(in: container.mainContext, preferences: preferences)

        let pushStarters = try container.mainContext.fetch(FetchDescriptor<WorkoutTemplate>())
            .filter { $0.isStarterRoutine && $0.name == "Push" }
        XCTAssertEqual(pushStarters.count, 1)
        XCTAssertEqual(pushStarters.first?.id, existingPush.id)
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
