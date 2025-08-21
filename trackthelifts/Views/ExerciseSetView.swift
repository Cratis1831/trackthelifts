//
//  ExerciseSetView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-14.
//

import SwiftUI
import SwiftData

struct ExerciseSetView: View {
    let exerciseSet: ExerciseSet
    @Environment(\.modelContext) private var modelContext
    
    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var isCompleted: Bool = false
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool

    var body: some View {
        GridRow {
            // Column 1: Set number
            Text("\(exerciseSet.order + 1)")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 32)
                .background(isCompleted ? Color.orange.opacity(0.3) : Color.gray.opacity(0.3))
                .cornerRadius(6)

            // Column 2 & 3: Previous summary (placeholder for now)
            Text("- -")
                .gridCellColumns(2)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(Color.secondary)

            // Column 4: weight
            TextField("0", text: $weight)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 50, height: 32)
                .background(isCompleted ? Color.orange.opacity(0.2) : Color.gray.opacity(0.3))
                .cornerRadius(6)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .disabled(isCompleted)
                .focused($isWeightFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: weight) { _, newValue in
                    updateExerciseSet()
                }
                .onSubmit {
                    isRepsFocused = true
                }

            // Column 5: reps
            TextField("0", text: $reps)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 50, height: 32)
                .background(isCompleted ? Color.orange.opacity(0.2) : Color.gray.opacity(0.3))
                .cornerRadius(6)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .disabled(isCompleted)
                .focused($isRepsFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: reps) { _, newValue in
                    updateExerciseSet()
                }
                .onSubmit {
                    isRepsFocused = false
                    isWeightFocused = false
                }

            // Column 6: checkmark
            Button {
                toggleCompletion()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .frame(width: 30, height: 32)
                    .foregroundColor(isCompleted ? .orange : Color.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            loadExerciseSetData()
        }
    }
    
    private func loadExerciseSetData() {
        weight = exerciseSet.weight > 0 ? String(exerciseSet.weight) : ""
        reps = exerciseSet.reps > 0 ? String(exerciseSet.reps) : ""
        isCompleted = exerciseSet.isCompleted
    }
    
    private func updateExerciseSet() {
        if let weightValue = Double(weight) {
            exerciseSet.weight = weightValue
        } else {
            exerciseSet.weight = 0
        }
        
        if let repsValue = Int(reps) {
            exerciseSet.reps = repsValue
        } else {
            exerciseSet.reps = 0
        }
        
        exerciseSet.updatedAt = .now
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to update exercise set: \(error)")
        }
    }
    
    private func toggleCompletion() {
        // Only allow completion if weight and reps are entered
        guard let weightValue = Double(weight), weightValue > 0,
              let repsValue = Int(reps), repsValue > 0 else {
            return
        }
        
        isCompleted.toggle()
        exerciseSet.isCompleted = isCompleted
        exerciseSet.updatedAt = .now
        
        // Update the exercise set with current values
        exerciseSet.weight = weightValue
        exerciseSet.reps = repsValue
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle completion: \(error)")
        }
    }
}

#Preview {
    let workout = Workout(title: "New Workout", date: .now)
    let exercise = Exercise(name: "Bench Press")
    let exerciseSet = ExerciseSet(weight: 135, reps: 8, order: 0, exercise: exercise, workout: workout)
    ExerciseSetView(exerciseSet: exerciseSet)
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseSet.self])
}
