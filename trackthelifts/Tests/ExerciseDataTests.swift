import SwiftData
import XCTest
@testable import trackthelifts

@MainActor
final class ExerciseDataTests: XCTestCase {
    private var preferences: UserDefaults!
    private var preferencesSuiteName: String!

    override func setUp() {
        super.setUp()
        preferencesSuiteName = "ExerciseDataTests.\(UUID().uuidString)"
        preferences = UserDefaults(suiteName: preferencesSuiteName)
    }

    override func tearDown() {
        preferences.removePersistentDomain(forName: preferencesSuiteName)
        preferences = nil
        preferencesSuiteName = nil
        super.tearDown()
    }

    func testBundledCatalogIsCompleteAndValid() {
        XCTAssertEqual(ExerciseData.defaultExercises.count, 137)

        let normalizedNames = Set(ExerciseData.defaultExercises.map {
            ExerciseData.normalizedName($0.name)
        })
        XCTAssertEqual(normalizedNames.count, ExerciseData.defaultExercises.count)

        let validBodyparts = Set(ExerciseData.defaultBodyparts)
        XCTAssertTrue(ExerciseData.defaultExercises.allSatisfy { validBodyparts.contains($0.bodypart) })
        XCTAssertTrue(ExerciseData.defaultExercises.allSatisfy { $0.category != .other })
        XCTAssertEqual(Set(ExerciseData.defaultExercises.map(\.category)), Set(ExerciseCategory.allCases.dropLast()))
    }

    func testFreshStoreReceivesCompleteLibrary() throws {
        let container = try makeContainer()

        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)

        let exercises = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        let bodyparts = try container.mainContext.fetch(FetchDescriptor<Bodypart>())
        XCTAssertEqual(exercises.count, 137)
        XCTAssertEqual(bodyparts.count, 13)
        XCTAssertEqual(preferences.integer(forKey: ExerciseData.libraryVersionKey), ExerciseData.libraryVersion)
        XCTAssertEqual(exercises.first(where: { $0.name == "Treadmill" })?.category, .cardio)
    }

    func testUpgradeMergesDefaultsAndPreservesExistingRecords() throws {
        let container = try makeContainer()
        let customBodypart = Bodypart(name: "Custom Body Part")
        let existingSquat = Exercise(name: "Squat", bodypart: customBodypart)
        let customExercise = Exercise(name: "My Custom Movement", bodypart: customBodypart)
        container.mainContext.insert(customBodypart)
        container.mainContext.insert(existingSquat)
        container.mainContext.insert(customExercise)
        try container.mainContext.save()

        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)

        var exercises = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.count, 138)
        XCTAssertEqual(exercises.first(where: { $0.id == existingSquat.id })?.bodypart?.name, "Custom Body Part")
        XCTAssertEqual(exercises.first(where: { $0.id == existingSquat.id })?.category, .barbell)
        XCTAssertNotNil(exercises.first(where: { $0.id == customExercise.id }))
        XCTAssertEqual(exercises.first(where: { $0.id == customExercise.id })?.category, .other)

        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)
        exercises = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.count, 138)
    }

    func testCurrentLibraryVersionDoesNotRestoreIndividuallyDeletedDefaults() throws {
        let container = try makeContainer()
        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)
        let exercises = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        container.mainContext.delete(exercises[0])
        try container.mainContext.save()

        ExerciseData.seedIfNeeded(in: container.mainContext, preferences: preferences)

        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Exercise>()), 136)
    }

    func testExerciseCountText() {
        XCTAssertEqual(ExerciseCountText.make(visibleCount: 137, totalCount: 137, isFiltering: false), "137 exercises")
        XCTAssertEqual(ExerciseCountText.make(visibleCount: 18, totalCount: 137, isFiltering: true), "18 of 137 exercises")
        XCTAssertEqual(ExerciseCountText.make(visibleCount: 0, totalCount: 137, isFiltering: true), "0 of 137 exercises")
        XCTAssertEqual(ExerciseCountText.make(visibleCount: 1, totalCount: 1, isFiltering: false), "1 exercise")
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Exercise.self, Bodypart.self,
            configurations: configuration
        )
    }
}
