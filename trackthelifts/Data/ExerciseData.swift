//
//  ExerciseData.swift
//  TrackTheLifts
//
//  Created by Claude on 2025-08-22.
//

import Foundation
import SwiftData

struct DefaultExercise: Equatable {
    let name: String
    let bodypart: String
    let category: ExerciseCategory
}

struct ExerciseData {
    static let libraryVersion = 2
    static let libraryVersionKey = "bundledExerciseLibraryVersion"

    static let defaultBodyparts = [
        "Chest",
        "Back",
        "Shoulders",
        "Biceps",
        "Triceps",
        "Forearms",
        "Quadriceps",
        "Hamstrings",
        "Glutes",
        "Calves",
        "Abs",
        "Full Body",
        "Cardio",
    ]

    static let defaultExercises: [DefaultExercise] = [
        // Chest
        .init(name: "Barbell Bench Press", bodypart: "Chest", category: .barbell),
        .init(name: "Incline Barbell Bench Press", bodypart: "Chest", category: .barbell),
        .init(name: "Decline Barbell Bench Press", bodypart: "Chest", category: .barbell),
        .init(name: "Dumbbell Bench Press", bodypart: "Chest", category: .dumbbell),
        .init(name: "Incline Dumbbell Press", bodypart: "Chest", category: .dumbbell),
        .init(name: "Dumbbell Flyes", bodypart: "Chest", category: .dumbbell),
        .init(name: "Cable Chest Fly", bodypart: "Chest", category: .cable),
        .init(name: "Chest Press Machine", bodypart: "Chest", category: .machine),
        .init(name: "Pec Deck Machine", bodypart: "Chest", category: .machine),
        .init(name: "Decline Dumbbell Bench Press", bodypart: "Chest", category: .dumbbell),
        .init(name: "Dumbbell Pullover", bodypart: "Chest", category: .dumbbell),
        .init(name: "Push-Up", bodypart: "Chest", category: .bodyweight),
        .init(name: "Chest Dip", bodypart: "Chest", category: .bodyweight),
        .init(name: "Smith Machine Bench Press", bodypart: "Chest", category: .machine),

        // Back
        .init(name: "Deadlift", bodypart: "Back", category: .barbell),
        .init(name: "Barbell Row", bodypart: "Back", category: .barbell),
        .init(name: "T-Bar Row", bodypart: "Back", category: .machine),
        .init(name: "Dumbbell Row", bodypart: "Back", category: .dumbbell),
        .init(name: "Cable Row", bodypart: "Back", category: .cable),
        .init(name: "Lat Pulldown", bodypart: "Back", category: .cable),
        .init(name: "Pull-ups", bodypart: "Back", category: .bodyweight),
        .init(name: "Cable Pullover", bodypart: "Back", category: .cable),
        .init(name: "Machine Row", bodypart: "Back", category: .machine),
        .init(name: "Pendlay Row", bodypart: "Back", category: .barbell),
        .init(name: "Rack Pull", bodypart: "Back", category: .barbell),
        .init(name: "Chest-Supported Dumbbell Row", bodypart: "Back", category: .dumbbell),
        .init(name: "Assisted Pull-Up", bodypart: "Back", category: .machine),
        .init(name: "Back Extension", bodypart: "Back", category: .bodyweight),
        .init(name: "Kettlebell Row", bodypart: "Back", category: .kettlebell),

        // Shoulders
        .init(name: "Overhead Press", bodypart: "Shoulders", category: .barbell),
        .init(name: "Dumbbell Shoulder Press", bodypart: "Shoulders", category: .dumbbell),
        .init(name: "Lateral Raises", bodypart: "Shoulders", category: .dumbbell),
        .init(name: "Front Raises", bodypart: "Shoulders", category: .dumbbell),
        .init(name: "Rear Delt Flyes", bodypart: "Shoulders", category: .dumbbell),
        .init(name: "Cable Lateral Raises", bodypart: "Shoulders", category: .cable),
        .init(name: "Machine Shoulder Press", bodypart: "Shoulders", category: .machine),
        .init(name: "Face Pulls", bodypart: "Shoulders", category: .cable),
        .init(name: "Arnold Press", bodypart: "Shoulders", category: .dumbbell),
        .init(name: "Barbell Upright Row", bodypart: "Shoulders", category: .barbell),
        .init(name: "Barbell Shrug", bodypart: "Shoulders", category: .barbell),
        .init(name: "Dumbbell Shrug", bodypart: "Shoulders", category: .dumbbell),
        .init(name: "Landmine Press", bodypart: "Shoulders", category: .barbell),
        .init(name: "Reverse Pec Deck", bodypart: "Shoulders", category: .machine),
        .init(name: "Kettlebell Shoulder Press", bodypart: "Shoulders", category: .kettlebell),

        // Biceps
        .init(name: "Barbell Curl", bodypart: "Biceps", category: .barbell),
        .init(name: "Dumbbell Curl", bodypart: "Biceps", category: .dumbbell),
        .init(name: "Hammer Curls", bodypart: "Biceps", category: .dumbbell),
        .init(name: "Cable Bicep Curl", bodypart: "Biceps", category: .cable),
        .init(name: "Preacher Curls", bodypart: "Biceps", category: .machine),
        .init(name: "Cable Hammer Curls", bodypart: "Biceps", category: .cable),
        .init(name: "EZ-Bar Curl", bodypart: "Biceps", category: .barbell),
        .init(name: "Incline Dumbbell Curl", bodypart: "Biceps", category: .dumbbell),
        .init(name: "Concentration Curl", bodypart: "Biceps", category: .dumbbell),
        .init(name: "Spider Curl", bodypart: "Biceps", category: .barbell),
        .init(name: "Machine Biceps Curl", bodypart: "Biceps", category: .machine),

        // Triceps
        .init(name: "Close Grip Bench Press", bodypart: "Triceps", category: .barbell),
        .init(name: "Tricep Dips", bodypart: "Triceps", category: .bodyweight),
        .init(name: "Overhead Tricep Extension", bodypart: "Triceps", category: .dumbbell),
        .init(name: "Cable Tricep Pushdown", bodypart: "Triceps", category: .cable),
        .init(name: "Dumbbell Tricep Extension", bodypart: "Triceps", category: .dumbbell),
        .init(name: "Cable Overhead Extension", bodypart: "Triceps", category: .cable),
        .init(name: "EZ-Bar Skull Crusher", bodypart: "Triceps", category: .barbell),
        .init(name: "Dumbbell Skull Crusher", bodypart: "Triceps", category: .dumbbell),
        .init(name: "Dumbbell Triceps Kickback", bodypart: "Triceps", category: .dumbbell),
        .init(name: "Rope Triceps Pushdown", bodypart: "Triceps", category: .cable),
        .init(name: "Assisted Dip Machine", bodypart: "Triceps", category: .machine),

        // Forearms
        .init(name: "Barbell Wrist Curls", bodypart: "Forearms", category: .barbell),
        .init(name: "Dumbbell Wrist Curls", bodypart: "Forearms", category: .dumbbell),
        .init(name: "Reverse Barbell Curls", bodypart: "Forearms", category: .barbell),
        .init(name: "Cable Wrist Curls", bodypart: "Forearms", category: .cable),
        .init(name: "Barbell Reverse Wrist Curl", bodypart: "Forearms", category: .barbell),
        .init(name: "Dumbbell Reverse Wrist Curl", bodypart: "Forearms", category: .dumbbell),
        .init(name: "Dumbbell Farmer’s Carry", bodypart: "Forearms", category: .dumbbell),
        .init(name: "Kettlebell Farmer’s Carry", bodypart: "Forearms", category: .kettlebell),

        // Quadriceps
        .init(name: "Squat", bodypart: "Quadriceps", category: .barbell),
        .init(name: "Front Squat", bodypart: "Quadriceps", category: .barbell),
        .init(name: "Leg Press", bodypart: "Quadriceps", category: .machine),
        .init(name: "Bulgarian Split Squats", bodypart: "Quadriceps", category: .bodyweight),
        .init(name: "Dumbbell Lunges", bodypart: "Quadriceps", category: .dumbbell),
        .init(name: "Leg Extension", bodypart: "Quadriceps", category: .machine),
        .init(name: "Hack Squat", bodypart: "Quadriceps", category: .machine),
        .init(name: "Smith Machine Squat", bodypart: "Quadriceps", category: .machine),
        .init(name: "Dumbbell Goblet Squat", bodypart: "Quadriceps", category: .dumbbell),
        .init(name: "Kettlebell Goblet Squat", bodypart: "Quadriceps", category: .kettlebell),
        .init(name: "Barbell Lunge", bodypart: "Quadriceps", category: .barbell),
        .init(name: "Dumbbell Step-Up", bodypart: "Quadriceps", category: .dumbbell),
        .init(name: "Pendulum Squat", bodypart: "Quadriceps", category: .machine),
        .init(name: "Belt Squat", bodypart: "Quadriceps", category: .machine),
        .init(name: "Kettlebell Reverse Lunge", bodypart: "Quadriceps", category: .kettlebell),

        // Hamstrings
        .init(name: "Romanian Deadlift", bodypart: "Hamstrings", category: .barbell),
        .init(name: "Leg Curls", bodypart: "Hamstrings", category: .machine),
        .init(name: "Stiff Leg Deadlift", bodypart: "Hamstrings", category: .barbell),
        .init(name: "Dumbbell Romanian Deadlift", bodypart: "Hamstrings", category: .dumbbell),
        .init(name: "Seated Leg Curl", bodypart: "Hamstrings", category: .machine),
        .init(name: "Lying Leg Curl", bodypart: "Hamstrings", category: .machine),
        .init(name: "Barbell Good Morning", bodypart: "Hamstrings", category: .barbell),
        .init(name: "Nordic Hamstring Curl", bodypart: "Hamstrings", category: .bodyweight),
        .init(name: "Kettlebell Romanian Deadlift", bodypart: "Hamstrings", category: .kettlebell),
        .init(name: "Kettlebell Deadlift", bodypart: "Hamstrings", category: .kettlebell),

        // Glutes
        .init(name: "Hip Thrust", bodypart: "Glutes", category: .bodyweight),
        .init(name: "Barbell Hip Thrust", bodypart: "Glutes", category: .barbell),
        .init(name: "Dumbbell Hip Thrust", bodypart: "Glutes", category: .dumbbell),
        .init(name: "Cable Kickbacks", bodypart: "Glutes", category: .cable),
        .init(name: "Glute Bridge", bodypart: "Glutes", category: .bodyweight),
        .init(name: "Smith Machine Hip Thrust", bodypart: "Glutes", category: .machine),
        .init(name: "Machine Glute Kickback", bodypart: "Glutes", category: .machine),
        .init(name: "Hip Abduction Machine", bodypart: "Glutes", category: .machine),

        // Calves
        .init(name: "Calf Raise", bodypart: "Calves", category: .bodyweight),
        .init(name: "Seated Calf Raise", bodypart: "Calves", category: .machine),
        .init(name: "Dumbbell Calf Raise", bodypart: "Calves", category: .dumbbell),
        .init(name: "Machine Calf Raise", bodypart: "Calves", category: .machine),
        .init(name: "Leg Press Calf Raise", bodypart: "Calves", category: .machine),
        .init(name: "Smith Machine Calf Raise", bodypart: "Calves", category: .machine),
        .init(name: "Donkey Calf Raise", bodypart: "Calves", category: .bodyweight),

        // Abs
        .init(name: "Plank", bodypart: "Abs", category: .bodyweight),
        .init(name: "Cable Crunches", bodypart: "Abs", category: .cable),
        .init(name: "Russian Twists", bodypart: "Abs", category: .bodyweight),
        .init(name: "Machine Crunches", bodypart: "Abs", category: .machine),
        .init(name: "Hanging Leg Raise", bodypart: "Abs", category: .bodyweight),
        .init(name: "Hanging Knee Raise", bodypart: "Abs", category: .bodyweight),
        .init(name: "Ab Wheel Rollout", bodypart: "Abs", category: .bodyweight),
        .init(name: "Decline Sit-Up", bodypart: "Abs", category: .bodyweight),
        .init(name: "Bicycle Crunch", bodypart: "Abs", category: .bodyweight),
        .init(name: "Cable Woodchop", bodypart: "Abs", category: .cable),
        .init(name: "Pallof Press", bodypart: "Abs", category: .cable),

        // Full Body
        .init(name: "Kettlebell Swing", bodypart: "Full Body", category: .kettlebell),
        .init(name: "Kettlebell Clean", bodypart: "Full Body", category: .kettlebell),
        .init(name: "Kettlebell Snatch", bodypart: "Full Body", category: .kettlebell),
        .init(name: "Turkish Get-Up", bodypart: "Full Body", category: .kettlebell),

        // Cardio
        .init(name: "Treadmill", bodypart: "Cardio", category: .cardio),
        .init(name: "Elliptical", bodypart: "Cardio", category: .cardio),
        .init(name: "Stair Climber", bodypart: "Cardio", category: .cardio),
        .init(name: "Stationary Bike", bodypart: "Cardio", category: .cardio),
        .init(name: "Recumbent Bike", bodypart: "Cardio", category: .cardio),
        .init(name: "Rowing Machine", bodypart: "Cardio", category: .cardio),
        .init(name: "Air Bike", bodypart: "Cardio", category: .cardio),
        .init(name: "SkiErg", bodypart: "Cardio", category: .cardio),
    ]

    /// Installs or upgrades the bundled library once per catalog version. User-created exercises
    /// and edits are preserved; only a missing category on a recognized built-in is backfilled.
    static func seedIfNeeded(
        in modelContext: ModelContext,
        preferences: UserDefaults = .standard
    ) {
        let existingExercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        let installedVersion = preferences.integer(forKey: libraryVersionKey)
        guard existingExercises.isEmpty || installedVersion < libraryVersion else { return }

        let existingBodyparts = (try? modelContext.fetch(FetchDescriptor<Bodypart>())) ?? []
        var bodypartsByName: [String: Bodypart] = [:]
        for bodypart in existingBodyparts {
            bodypartsByName[normalizedName(bodypart.name)] = bodypart
        }

        for name in defaultBodyparts where bodypartsByName[normalizedName(name)] == nil {
            let bodypart = Bodypart(name: name)
            modelContext.insert(bodypart)
            bodypartsByName[normalizedName(name)] = bodypart
        }

        var exercisesByName: [String: Exercise] = [:]
        for exercise in existingExercises where exercisesByName[normalizedName(exercise.name)] == nil {
            exercisesByName[normalizedName(exercise.name)] = exercise
        }

        for definition in defaultExercises {
            let normalizedExerciseName = normalizedName(definition.name)
            if let existingExercise = exercisesByName[normalizedExerciseName] {
                if existingExercise.category == .other {
                    existingExercise.category = definition.category
                    existingExercise.updatedAt = .now
                }
                continue
            }

            let exercise = Exercise(
                name: definition.name,
                bodypart: bodypartsByName[normalizedName(definition.bodypart)],
                category: definition.category
            )
            modelContext.insert(exercise)
            exercisesByName[normalizedExerciseName] = exercise
        }

        do {
            try modelContext.save()
            preferences.set(libraryVersion, forKey: libraryVersionKey)
        } catch {
            print("Failed to install bundled exercise library: \(error)")
        }
    }

    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
