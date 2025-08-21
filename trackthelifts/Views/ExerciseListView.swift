//
//  ExercisesView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftData
import SwiftUI

struct ExerciseListView: View {
    var chooseExercise: Bool = false
    var onExerciseSelected: ((Exercise) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    var body: some View {
        List {
            ForEach(exercises) { exercise in
                Button {
                    onExerciseSelected?(exercise)
                } label: {
                    Text(exercise.name)
                }
            }

            if exercises.isEmpty {
                Text("No exercises yet.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Exercises")
        .onAppear {
            if exercises.isEmpty {
                let defaults = [
                    "Squat", "Bench Press", "Deadlift", "Overhead Press",
                    "Barbell Row",
                ]
                for name in defaults {
                    modelContext.insert(Exercise(name: name))
                }

                do {
                    try modelContext.save()
                } catch {
                    print(
                        "Failed to save default exercises: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    func addExercise(from template: Exercise, to workout: Workout) {
        let newExerciseSet = ExerciseSet(
            weight: 0.0,
            reps: 0,
            order: workout.exerciseSets.count,
            exercise: template,
            workout: workout
        )
        workout.exerciseSets.append(newExerciseSet)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Exercise.self, ExerciseSet.self, Workout.self,
        configurations: config
    )

    let mockExercises = [
        Exercise(name: "Squat"),
        Exercise(name: "Bench Press"),
        Exercise(name: "Deadlift"),
    ]

    for ex in mockExercises {
        container.mainContext.insert(ex)
    }

    return ExerciseListView()
        .modelContainer(container)
}
