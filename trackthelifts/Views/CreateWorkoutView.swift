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
    @FocusState private var focusWorkoutName: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var dataFilled: Bool {
        !workoutName.isEmpty
    }
    var body: some View {
        NavigationStack {
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

                    Button(action: {
                        //                        saveWorkout()
                        showExerciseList.toggle()
                    }) {
                        Text("Add Exercise")
                            .foregroundColor(Color(.label))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color(.tintColor))
                            .cornerRadius(10)
                    }
                    if let workout = savedWorkout, !workout.exerciseSets.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Exercises")
                                .font(.headline)
                                .padding(.top)
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
                                .foregroundColor(.primary)
                                
                                ForEach(Array(Dictionary(grouping: workout.exerciseSets, by: \.exercise.name).sorted(by: { $0.key < $1.key })), id: \.key) { exerciseName, exerciseSets in
                                    Section(header: Text(exerciseName)) {
                                        ForEach(exerciseSets.sorted(by: { $0.order < $1.order })) { exerciseSet in
                                            GridRow {
                                                ExerciseSetView(
                                                    workout: workout,
                                                    exercise: exerciseSet.exercise,
                                                    setNumber: exerciseSet.order + 1
                                                )
                                                .padding(.vertical, 2)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .onAppear {
                focusWorkoutName = true
            }
            .sheet(isPresented: $showExerciseList) {
                ExerciseListView(chooseExercise: true) { selectedTemplate in
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
                }
            }

            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading,
                    content: {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.primary)
                                .font(.headline)
                                .frame(width: 36, height: 36)
                                .background(Color(.white.opacity(0.3)))
                                .clipShape(Circle())
                        }
                    }
                )
            }
        }
    }

    func saveWorkout() {
        let newWorkout = Workout(
// Replace with actual user ID
            title: workoutName,
            date: .now,
            notes: workoutNotes
        )
        modelContext.insert(newWorkout)
        
        do {
            try modelContext.save()
            savedWorkout = newWorkout
            // ⛔️ don't call dismiss() here — maybe only when explicitly exiting
        } catch {
            print("Failed to save workout: \(error.localizedDescription)")
        }
    }

}

#Preview {
    CreateWorkoutView()
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseSet.self])
}
