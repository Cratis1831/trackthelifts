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
    @State private var prAnnouncement: String?
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
                            .textFieldStyle(.roundedBorder)
                            .focused($focusWorkoutName)
                        TextField("Workout Notes", text: $workoutNotes)
                            .font(.subheadline.bold())
                            .textFieldStyle(.roundedBorder)

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

                        RestTimerBanner()
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
                                            ExerciseSetView(exerciseSet: exerciseSet) { set, kind in
                                                showPersonalRecord(for: set, kind: kind)
                                            }
                                        }
                                    }
                                    
                                    // Add Set button
                                    Button {
                                        addNewSet(for: exerciseSets.first?.exercise, to: workout)
                                    } label: {
                                        Text("Add Set")
                                            .foregroundColor(.orange)
                                            .frame(maxWidth: .infinity, minHeight: 38)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.orange.opacity(0.15))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, -6)
                                    .padding(.top, 8)
                                }
                                .padding(.bottom, 16)
                            }
                        }
                        
                        // Add Exercise Button (moved after exercises)
                        Button("Add Exercise") {
                            showExerciseList.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .tint(.orange)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .padding(.horizontal, -6)
                        .padding(.top, 16)
                    } else {
                        // Add Exercise Button when no exercises exist
                        Button("Add Exercise") {
                            showExerciseList.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .tint(.orange)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .padding(.horizontal, -6)
                        .padding(.top, 16)
                    }
                    }
                }
                .padding()
                
                Spacer()
                
                // Finish Workout Button at bottom (only show if workout exists and has exercises)
                if let workout = savedWorkout, !workout.exerciseSets.isEmpty {
                    VStack {
                        Button("Finish Workout") {
                            finishWorkout()
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .tint(.green)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 30)
                    }
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
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCancelConfirmation = true
                    } label: {
                        Text("Cancel Workout")
                            .foregroundColor(.primary)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(.glass)
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
        .overlay(alignment: .top) {
            if let prAnnouncement {
                Text(prAnnouncement)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.yellow)
                    .cornerRadius(20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func showPersonalRecord(for set: ExerciseSet, kind: PRKind) {
        let label = kind == .weight ? "New weight PR!" : "New estimated 1RM PR!"
        withAnimation {
            prAnnouncement = "🏆 \(set.exercise.name): \(label)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                prAnnouncement = nil
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
        RestTimerManager.shared.cancel()
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
            RestTimerManager.shared.cancel()
            dismiss()
        } catch {
            print("Failed to complete workout: \(error)")
        }
    }
    
    private func addNewSet(for exercise: Exercise?, to workout: Workout) {
        guard let exercise = exercise else { return }
        
        let existingSetsForExercise = workout.exerciseSets.filter { $0.exercise == exercise }
        let lastSet = existingSetsForExercise.max { $0.order < $1.order }
        let newOrder = lastSet?.order ?? -1

        let newExerciseSet = ExerciseSet(
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 0,
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

struct RestTimerBanner: View {
    @State private var now = Date()
    private let manager = RestTimerManager.shared
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var remainingSeconds: Int {
        guard let endDate = manager.endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSince(now).rounded()))
    }

    var body: some View {
        if manager.isRunning {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
                Text("Rest: \(formattedTime(remainingSeconds))")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("+15s") {
                    manager.addTime(15)
                }
                .font(.system(size: 13, weight: .medium))
                Button("Skip") {
                    manager.cancel()
                }
                .font(.system(size: 13, weight: .medium))
            }
            .padding(10)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .cornerRadius(10)
            .onReceive(ticker) { value in
                now = value
            }
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    CreateWorkoutView()
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseSet.self])
}
