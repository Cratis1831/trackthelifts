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

    func testStarterRoutinesDoNotConsumeFreeSlots() {
        XCTAssertEqual(
            SubscriptionAccessPolicy.userCreatedRoutineCount(from: []),
            0
        )
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 0, tier: .free))
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 2, tier: .free))
        XCTAssertFalse(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 3, tier: .free))
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
        XCTAssertTrue(templates.allSatisfy(\.isPrebuilt))
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

        XCTAssertFalse(copy.isPrebuilt)
        XCTAssertEqual(
            SubscriptionAccessPolicy.userCreatedRoutineCount(
                from: try container.mainContext.fetch(FetchDescriptor<WorkoutTemplate>())
            ),
            1
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
