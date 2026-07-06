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
    var onPersonalRecord: ((ExerciseSet, PRKind) -> Void)? = nil
    /// When set, this view claims focus for its weight field if its id matches the pending value,
    /// then clears the binding so the focus request only fires once.
    var autoFocusSetID: Binding<UUID?>? = nil
    @Environment(\.modelContext) private var modelContext

    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var isCompleted: Bool = false
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool

    var body: some View {
        HStack {
            // Column 1: Set number
            Text("\(exerciseSet.order + 1)")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 32)
                .background(isPersonalRecord ? Color.yellow.opacity(0.4) : (isCompleted ? Color.appAccent.opacity(0.3) : Color.gray.opacity(0.3)))
                .cornerRadius(6)

            // Column 2 & 3: Previous summary (last time this exercise/set-number was logged)
            Text(previousSetSummary)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(Color.secondary)

            // Column 4: weight
            TextField("0", text: $weight)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 50, height: 32)
                .textFieldStyle(.roundedBorder)
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
                .textFieldStyle(.roundedBorder)
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
                    .foregroundColor(isCompleted ? .appAccent : Color.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            loadExerciseSetData()
            if let autoFocusSetID, autoFocusSetID.wrappedValue == exerciseSet.id {
                isWeightFocused = true
                autoFocusSetID.wrappedValue = nil
            }
        }
    }
    
    private var isPersonalRecord: Bool {
        guard isCompleted else { return false }
        return PersonalRecordService.personalRecord(for: exerciseSet, in: modelContext) != nil
    }

    private var previousSetSummary: String {
        guard let previous = fetchPreviousSet() else { return "- -" }
        return "\(previous.weight.formattedWeight) \(WeightUnitPreference.shared.unit.label) x \(previous.reps)"
    }

    private func fetchPreviousSet() -> ExerciseSet? {
        let exerciseID = exerciseSet.exercise.id
        let workoutID = exerciseSet.workout.id
        let order = exerciseSet.order
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> { set in
                set.exercise.id == exerciseID && set.workout.id != workoutID && set.order == order
                    && set.workout.completedAt != nil && !set.workout.isDeleted
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func loadExerciseSetData() {
        weight = exerciseSet.weight > 0 ? exerciseSet.weight.formattedWeight : ""
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
        // Weight is optional (defaults to 0, e.g. for bodyweight exercises), but reps are required.
        let weightValue = Double(weight) ?? 0
        guard let repsValue = Int(reps), repsValue > 0 else {
            return
        }

        let wasCompleted = isCompleted
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

        if !wasCompleted && isCompleted {
            Haptics.impact(.light)
            RestTimerManager.shared.startTimer(for: exerciseSet.exercise.name)
            if let prKind = PersonalRecordService.personalRecord(for: exerciseSet, in: modelContext) {
                onPersonalRecord?(exerciseSet, prKind)
            }
        } else if wasCompleted && !isCompleted {
            Haptics.selection()
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
