//
//  CreateWorkoutView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-05.
//

import SwiftData
import SwiftUI

struct CreateWorkoutView: View {
    @State private var workoutName: String = ""
    @State private var workoutNotes: String = ""
    @State private var showExerciseList: Bool = false
    @State private var savedWorkout: Workout?
    @State private var showCancelConfirmation: Bool = false
    private let sessionManager = WorkoutSessionManager.shared
    @FocusState private var focusWorkoutName: Bool
    
    // Add initializer to handle existing workout
    let existingWorkout: Workout?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(existingWorkout: Workout? = nil) {
        self.existingWorkout = existingWorkout
    }

    var dataFilled: Bool {
        !workoutName.isEmpty
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        
                        TextField("Workout Name", text: $workoutName)
                            .font(.title.bold())
                            .padding()
                            .textFieldStyle(.plain)
                            .focused($focusWorkoutName)
                        TextField("Workout Notes", text: $workoutNotes)
                            .font(.subheadline.bold())
                            .padding()
                            .textFieldStyle(.plain)

                        //align leading
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(Color(.secondaryLabel))
                            //                        Display the date in this format "Saturday, July 5th, 2025
                            Text(
                                Date().formatted(
                                    .dateTime.weekday(.wide).month(.wide).day()
                                        .year()
                                )
                            )
                            .foregroundColor(Color(.secondaryLabel))
                        }
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(Color(.secondaryLabel))
                            TimerView()
                        }
                        .padding(.bottom)

                        if let workout = savedWorkout, !workout.exerciseSets.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Exercises")
                                    .font(.headline)
                                    .padding(.top)
                                
                                ForEach(Array(Dictionary(grouping: workout.exerciseSets, by: \.exercise.name).sorted(by: { $0.key < $1.key })), id: \.key) { exerciseName, exerciseSets in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Exercise name header
                                        HStack {
                                            Text(exerciseName)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                        
                                        // Grid for this exercise
                                        Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                                        // Header
                                        GridRow {
                                            Text("Set")
                                                .frame(width: 30, alignment: .center)
                                            
                                            Text("Previous")
                                                .gridCellColumns(2)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                            
                                            Text("lbs")
                                                .frame(width: 50, alignment: .center)
                                            
                                            Text("Reps")
                                                .frame(width: 50, alignment: .center)
                                            
                                            Image(systemName: "checkmark")
                                                .frame(width: 30, alignment: .center)
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        
                                        // Exercise sets
                                        ForEach(exerciseSets.sorted(by: { $0.order < $1.order })) { exerciseSet in
                                            ExerciseSetView(exerciseSet: exerciseSet)
                                        }
                                    }
                                    
                                    // Add Set button centered under each exercise
                                    Button(action: {
                                        addNewSet(for: exerciseSets.first?.exercise, to: workout)
                                    }) {
                                        Text("Add Set")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 14, weight: .medium))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.orange.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    .padding(.top, 8)
                                }
                                .padding(.bottom, 16)
                            }
                        }
                        
                        // Add Exercise Button (moved after exercises)
                        Button(action: {
                            showExerciseList.toggle()
                        }) {
                            Text("Add Exercise")
                                .foregroundColor(Color(.label))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color(.tintColor))
                                .cornerRadius(10)
                        }
                        .padding(.top, 16)
                    } else {
                        // Add Exercise Button when no exercises exist
                        Button(action: {
                            showExerciseList.toggle()
                        }) {
                            Text("Add Exercise")
                                .foregroundColor(Color(.label))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color(.tintColor))
                                .cornerRadius(10)
                        }
                        .padding(.top, 16)
                    }
                    }
                }
                .padding()
                
                Spacer()
                
                // Finish Workout Button at bottom (only show if workout exists and has exercises)
                if let workout = savedWorkout, !workout.exerciseSets.isEmpty {
                    VStack {
                        Button(action: {
                            finishWorkout()
                        }) {
                            Text("Finish Workout")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .onAppear {
                // Load existing workout data if resuming
                if let existingWorkout = existingWorkout {
                    savedWorkout = existingWorkout
                    workoutName = existingWorkout.title
                    workoutNotes = existingWorkout.notes ?? ""
                    focusWorkoutName = false // Don't auto-focus if resuming
                } else {
                    focusWorkoutName = true
                }
            }
            .sheet(isPresented: $showExerciseList) {
                ExerciseListView(chooseExercise: true, onExerciseSelected: { selectedTemplate in
                    // Ensure we have a saved workout
                    if savedWorkout == nil {
                        saveWorkout()
                    }

                    if let workout = savedWorkout {
                        let newExerciseSet = ExerciseSet(
                            weight: 0,
                            reps: 0,
                            order: workout.exerciseSets.filter { $0.exercise == selectedTemplate }.count,
                            exercise: selectedTemplate, 
                            workout: workout
                        )
                        workout.exerciseSets.append(newExerciseSet)
                        modelContext.insert(newExerciseSet)

                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to save exercise: \(error.localizedDescription)")
                        }
                    }

                    showExerciseList = false
                })
            }

            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        minimizeWorkout()
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.primary)
                            .font(.headline)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemBackground).opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCancelConfirmation = true
                    } label: {
                        Text("Cancel Workout")
                            .foregroundColor(.primary)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .alert("Cancel Workout", isPresented: $showCancelConfirmation) {
                Button("Continue Workout", role: .cancel) { }
                Button("Cancel Workout", role: .destructive) {
                    cancelWorkout()
                }
            } message: {
                Text("Are you sure you want to cancel this workout? Any unsaved changes will be lost.")
            }
        }
    }

    func saveWorkout() {
        // If we already have a saved workout (resuming), just update its properties
        if let existingWorkout = savedWorkout {
            existingWorkout.title = workoutName
            existingWorkout.notes = workoutNotes
            existingWorkout.updatedAt = .now
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to update workout: \(error.localizedDescription)")
            }
            return
        }
        
        // Create new workout
        let newWorkout = Workout(
            title: workoutName,
            date: .now,
            notes: workoutNotes
        )
        modelContext.insert(newWorkout)
        
        do {
            try modelContext.save()
            savedWorkout = newWorkout
            // Start tracking this workout as active
            sessionManager.startWorkout(workoutID: newWorkout.id)
        } catch {
            print("Failed to save workout: \(error.localizedDescription)")
        }
    }
    
    func minimizeWorkout() {
        // Save any changes to workout name/notes first if we have a workout
        if let workout = savedWorkout {
            workout.title = workoutName
            workout.notes = workoutNotes
            workout.updatedAt = .now
            
            do {
                try modelContext.save()
                sessionManager.minimizeWorkout()
                dismiss()
            } catch {
                print("Failed to save workout changes: \(error)")
            }
        } else {
            // If no workout has been created yet, just dismiss normally
            dismiss()
        }
    }
    
    private func cancelWorkout() {
        // If there's a saved workout and it has no exercises, delete it
        if let workout = savedWorkout, workout.exerciseSets.isEmpty {
            modelContext.delete(workout)
            try? modelContext.save()
            sessionManager.completeWorkout()
        }
        dismiss()
    }
    
    func finishWorkout() {
        guard let workout = savedWorkout else { return }
        
        workout.isActive = false
        workout.completedAt = .now
        workout.updatedAt = .now
        
        do {
            try modelContext.save()
            sessionManager.completeWorkout()
            dismiss()
        } catch {
            print("Failed to complete workout: \(error)")
        }
    }
    
    private func addNewSet(for exercise: Exercise?, to workout: Workout) {
        guard let exercise = exercise else { return }
        
        let existingSetsForExercise = workout.exerciseSets.filter { $0.exercise == exercise }
        let newOrder = existingSetsForExercise.map { $0.order }.max() ?? -1
        
        let newExerciseSet = ExerciseSet(
            weight: 0,
            reps: 0,
            order: newOrder + 1,
            exercise: exercise,
            workout: workout
        )
        
        workout.exerciseSets.append(newExerciseSet)
        modelContext.insert(newExerciseSet)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to add new set: \(error)")
        }
    }
}
#Preview {
    CreateWorkoutView()
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseSet.self])
}
