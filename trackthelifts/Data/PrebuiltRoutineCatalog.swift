import Foundation
import SwiftData

/// Bundled starter routines. They are free, seeded once per catalog version, and do not
/// count toward the three custom routines Free can create.
enum PrebuiltRoutineCatalog {
    static let catalogVersion = 1
    static let catalogVersionKey = "bundledPrebuiltRoutineCatalogVersion"

    struct ExerciseTarget: Equatable {
        let name: String
        let sets: Int
        let reps: Int
    }

    struct Recipe: Equatable {
        let id: UUID
        let name: String
        let exercises: [ExerciseTarget]
    }

    static let recipes: [Recipe] = [
        Recipe(
            id: UUID(uuidString: "7A900001-3100-4000-8000-000000000001")!,
            name: "Push",
            exercises: [
                .init(name: "Barbell Bench Press", sets: 3, reps: 8),
                .init(name: "Incline Dumbbell Press", sets: 3, reps: 8),
                .init(name: "Overhead Press", sets: 3, reps: 8),
                .init(name: "Lateral Raises", sets: 3, reps: 12),
                .init(name: "Cable Tricep Pushdown", sets: 3, reps: 10),
                .init(name: "Chest Dip", sets: 3, reps: 8),
            ]
        ),
        Recipe(
            id: UUID(uuidString: "7A900001-3100-4000-8000-000000000002")!,
            name: "Pull",
            exercises: [
                .init(name: "Deadlift", sets: 3, reps: 5),
                .init(name: "Pull-ups", sets: 3, reps: 8),
                .init(name: "Barbell Row", sets: 3, reps: 8),
                .init(name: "Lat Pulldown", sets: 3, reps: 10),
                .init(name: "Face Pulls", sets: 3, reps: 12),
                .init(name: "Barbell Curl", sets: 3, reps: 10),
            ]
        ),
        Recipe(
            id: UUID(uuidString: "7A900001-3100-4000-8000-000000000003")!,
            name: "Legs",
            exercises: [
                .init(name: "Squat", sets: 3, reps: 8),
                .init(name: "Romanian Deadlift", sets: 3, reps: 8),
                .init(name: "Leg Press", sets: 3, reps: 10),
                .init(name: "Leg Curls", sets: 3, reps: 10),
                .init(name: "Hip Thrust", sets: 3, reps: 10),
                .init(name: "Calf Raise", sets: 3, reps: 12),
            ]
        ),
        Recipe(
            id: UUID(uuidString: "7A900001-3100-4000-8000-000000000004")!,
            name: "Full Body",
            exercises: [
                .init(name: "Squat", sets: 3, reps: 5),
                .init(name: "Barbell Bench Press", sets: 3, reps: 5),
                .init(name: "Barbell Row", sets: 3, reps: 8),
                .init(name: "Overhead Press", sets: 3, reps: 8),
                .init(name: "Romanian Deadlift", sets: 3, reps: 8),
            ]
        ),
    ]

    static func seedIfNeeded(
        in modelContext: ModelContext,
        preferences: UserDefaults = .standard
    ) {
        let existingTemplates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let installedVersion = preferences.integer(forKey: catalogVersionKey)
        guard existingTemplates.isEmpty || installedVersion < catalogVersion else { return }

        let existingIDs = Set(existingTemplates.map(\.id))
        let exercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        var exercisesByName: [String: Exercise] = [:]
        for exercise in exercises {
            exercisesByName[ExerciseData.normalizedName(exercise.name)] = exercise
        }

        for recipe in recipes {
            guard existingIDs.contains(recipe.id) == false else { continue }

            let resolved = recipe.exercises.compactMap { target -> (Exercise, ExerciseTarget)? in
                exercisesByName[ExerciseData.normalizedName(target.name)].map { ($0, target) }
            }
            guard !resolved.isEmpty else { continue }

            let template = WorkoutTemplate(
                id: recipe.id,
                name: recipe.name,
                isPrebuilt: true
            )
            modelContext.insert(template)

            for (index, (exercise, target)) in resolved.enumerated() {
                let templateExercise = WorkoutTemplateExercise(
                    order: index,
                    targetSets: target.sets,
                    targetReps: target.reps,
                    targetWeight: 0,
                    template: template,
                    exercise: exercise
                )
                modelContext.insert(templateExercise)
                template.templateExercises.append(templateExercise)
            }
        }

        do {
            try modelContext.save()
            preferences.set(catalogVersion, forKey: catalogVersionKey)
        } catch {
            print("Failed to install starter routines: \(error)")
        }
    }
}
