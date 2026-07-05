//
//  WorkoutDetailView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

/// Editable detail view for a workout (typically a completed one, reached from History).
/// Lets the user rename the workout, edit set weight/reps/completion, add sets, and swipe to
/// remove an exercise (and all of its sets) entirely.
struct WorkoutDetailView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var modelContext

    /// Exercise names in their persisted `exerciseOrder` (drag-reorderable by the user), falling
    /// back to earliest-created-set order for older data that predates `exerciseOrder`.
    private var groupedExerciseNames: [String] {
        let grouped = Dictionary(grouping: workout.exerciseSets, by: \.exercise.name)
        return grouped.keys.sorted { name1, name2 in
            let order1 = grouped[name1]?.map(\.exerciseOrder).min() ?? Int.max
            let order2 = grouped[name2]?.map(\.exerciseOrder).min() ?? Int.max
            if order1 != order2 { return order1 < order2 }
            let earliest1 = grouped[name1]?.map(\.createdAt).min() ?? .distantFuture
            let earliest2 = grouped[name2]?.map(\.createdAt).min() ?? .distantFuture
            return earliest1 < earliest2
        }
    }

    private func sets(for exerciseName: String) -> [ExerciseSet] {
        workout.exerciseSets
            .filter { $0.exercise.name == exerciseName }
            .sorted { $0.order < $1.order }
    }

    /// Reassigns sequential `exerciseOrder` values to every set after a drag-reorder.
    private func moveExercises(from source: IndexSet, to destination: Int) {
        var names = groupedExerciseNames
        names.move(fromOffsets: source, toOffset: destination)

        for (index, name) in names.enumerated() {
            for set in sets(for: name) {
                set.exerciseOrder = index
            }
        }

        persistWorkoutEdit()
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                Section {
                    TextField("Workout Name", text: $workout.title)
                        .font(.title.bold())
                        .textFieldStyle(.plain)
                        .onChange(of: workout.title) { _, _ in
                            persistWorkoutEdit()
                        }

                    TextField(
                        "Workout Notes",
                        text: Binding(
                            get: { workout.notes ?? "" },
                            set: { workout.notes = $0 }
                        )
                    )
                    .font(.subheadline.bold())
                    .textFieldStyle(.plain)
                    .onChange(of: workout.notes) { _, _ in
                        persistWorkoutEdit()
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(Color(.secondaryLabel))
                        Text(
                            workout.date.formatted(
                                .dateTime.weekday(.wide).month(.wide).day().year()
                            )
                        )
                        .foregroundColor(Color(.secondaryLabel))
                    }

                    if let completedAt = workout.completedAt {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(Color(.secondaryLabel))
                            Text(formattedDuration(from: workout.createdAt, to: completedAt))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                    }
                }
                .listRowBackground(Color.black)
                .listRowSeparator(.hidden)

                ForEach(groupedExerciseNames, id: \.self) { name in
                    Section {
                        columnHeader

                        ForEach(sets(for: name)) { set in
                            ExerciseSetView(exerciseSet: set)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteSet(set)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                        }

                        Button {
                            addSet(for: name)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Add Set")
                            }
                        }
                        .buttonStyle(WorkoutActionButtonStyle(tint: .orange, prominence: .plain))
                    } header: {
                        HStack {
                            Text(name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Button(role: .destructive) {
                                deleteExercise(named: name)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                            }
                        }
                    }
                    .listRowBackground(Color.black)
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: moveExercises)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if groupedExerciseNames.count > 1 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func formattedDuration(from startDate: Date, to endDate: Date) -> String {
        let totalSeconds = max(0, Int(endDate.timeIntervalSince(startDate)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    private var columnHeader: some View {
        HStack {
            Text("Set")
                .frame(width: 30, alignment: .center)

            Text("Previous")
                .frame(maxWidth: .infinity, alignment: .center)

            Text(WeightUnitPreference.shared.unit.label)
                .frame(width: 50, alignment: .center)

            Text("Reps")
                .frame(width: 50, alignment: .center)

            Image(systemName: "checkmark")
                .frame(width: 30, alignment: .center)
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }

    private func persistWorkoutEdit() {
        workout.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            print("Failed to save workout edit: \(error)")
        }
    }

    private func deleteExercise(named name: String) {
        for set in sets(for: name) {
            workout.exerciseSets.removeAll { $0.id == set.id }
            modelContext.delete(set)
        }
        persistWorkoutEdit()
    }

    /// Removes a set and renumbers the remaining sets for that exercise so "Set N" stays sequential.
    private func deleteSet(_ set: ExerciseSet) {
        let exercise = set.exercise
        workout.exerciseSets.removeAll { $0.id == set.id }
        modelContext.delete(set)

        let remaining = workout.exerciseSets
            .filter { $0.exercise.id == exercise.id }
            .sorted { $0.order < $1.order }
        for (index, remainingSet) in remaining.enumerated() {
            remainingSet.order = index
        }

        persistWorkoutEdit()
    }

    private func addSet(for exerciseName: String) {
        let existingSets = sets(for: exerciseName)
        guard let exercise = existingSets.first?.exercise else { return }
        let lastSet = existingSets.max { $0.order < $1.order }

        let newSet = ExerciseSet(
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 0,
            order: (lastSet?.order ?? -1) + 1,
            exerciseOrder: lastSet?.exerciseOrder ?? 0,
            exercise: exercise,
            workout: workout
        )
        workout.exerciseSets.append(newSet)
        modelContext.insert(newSet)
        persistWorkoutEdit()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, Exercise.self, Bodypart.self, ExerciseSet.self,
        configurations: config
    )

    let exercise = Exercise(name: "Bench Press")
    let workout = Workout(title: "Push Day", date: .now, completedAt: .now)
    container.mainContext.insert(exercise)
    container.mainContext.insert(workout)
    let set = ExerciseSet(weight: 135, reps: 8, order: 0, exercise: exercise, workout: workout)
    container.mainContext.insert(set)
    workout.exerciseSets.append(set)

    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
}
