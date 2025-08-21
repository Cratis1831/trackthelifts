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
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var refreshTrigger = false
    @State private var manualExercises: [Exercise] = []
    
    private var displayedExercises: [Exercise] {
        exercises.isEmpty ? manualExercises : exercises
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if displayedExercises.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                        
                        Text("No Exercises Found")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Tap 'Seed Exercises' to add default exercises")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button("Seed Exercises") {
                            forceSeedExercises()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                } else {
                    List {
                        ForEach(displayedExercises) { exercise in
                            Button {
                                if chooseExercise, let onExerciseSelected = onExerciseSelected {
                                    onExerciseSelected(exercise)
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if chooseExercise {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color(red: 0.11, green: 0.11, blue: 0.12))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Exercises")
            .toolbar {
                if chooseExercise {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.orange)
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            // For future: Add custom exercise functionality
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
        }
        .onAppear {
            print("🔍 ExerciseListView onAppear - Current exercise count: \(exercises.count)")
            loadExercises()
            if exercises.isEmpty && manualExercises.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    seedDefaultExercises()
                }
            }
        }
        .id(refreshTrigger)
    }
    
    private func seedDefaultExercises() {
        print("🌱 Starting seedDefaultExercises - Current count: \(exercises.count)")
        let defaults = [
            "Squat", "Bench Press", "Deadlift", "Overhead Press",
            "Barbell Row", "Incline Bench Press", "Romanian Deadlift",
            "Lat Pulldown", "Dumbbell Shoulder Press", "Barbell Curl",
            "Tricep Dips", "Leg Press", "Calf Raise", "Pull-ups"
        ]
        
        for name in defaults {
            let exercise = Exercise(name: name)
            modelContext.insert(exercise)
            print("➕ Inserted exercise: \(name)")
        }

        do {
            try modelContext.save()
            print("✅ Successfully seeded \(defaults.count) default exercises")
            
            // Force UI refresh and reload exercises
            DispatchQueue.main.async {
                loadExercises()
                refreshTrigger.toggle()
            }
        } catch {
            print("❌ Failed to save default exercises: \(error)")
        }
    }
    
    private func forceSeedExercises() {
        print("🚀 Force seeding exercises...")
        seedDefaultExercises()
    }
    
    private func loadExercises() {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\Exercise.name)]
        )
        
        do {
            let fetchedExercises = try modelContext.fetch(descriptor)
            manualExercises = fetchedExercises
            print("🔄 Loaded \(fetchedExercises.count) exercises manually")
        } catch {
            print("❌ Failed to manually load exercises: \(error)")
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
