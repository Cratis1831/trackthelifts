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
    @State private var isReorderingExercises = false

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

    /// Reassigns sequential `exerciseOrder` values to every set after a drag-reorder. Only called
    /// from reorder mode, where the ForEach is a flat one-row-per-exercise list — the sole
    /// `.onMove` configuration List supports reliably (moving multi-row Sections crashes the
    /// List's index mapping).
    private func moveExercises(from source: IndexSet, to destination: Int) {
        var names = groupedExerciseNames
        guard source.allSatisfy({ $0 < names.count }), destination <= names.count else { return }
        names.move(fromOffsets: source, toOffset: destination)

        for (index, name) in names.enumerated() {
            for set in sets(for: name) {
                set.exerciseOrder = index
            }
        }

        persistWorkoutEdit()
        Haptics.impact(.light)
    }

    /// Exercise name row: long-press it (or tap its grip icon) to enter reorder mode.
    private func exerciseTitleRow(_ name: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            if groupedExerciseNames.count > 1 {
                Button {
                    Haptics.selection()
                    withAnimation {
                        isReorderingExercises = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                deleteExercise(named: name)
            } label: {
                IconTile(color: Color(red: 0.90, green: 0.30, blue: 0.24), size: 28) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onLongPressGesture {
            if groupedExerciseNames.count > 1 {
                Haptics.selection()
                withAnimation {
                    isReorderingExercises = true
                }
            }
        }
    }

    /// Compact reorder mode: the workout collapses to one draggable row per exercise.
    @ViewBuilder
    private var reorderModeContent: some View {
        Section {
            ForEach(groupedExerciseNames, id: \.self) { name in
                HStack(spacing: 12) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(sets(for: name).count) set\(sets(for: name).count == 1 ? "" : "s")")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .padding(.vertical, 4)
            }
            .onMove(perform: moveExercises)
        } header: {
            Text("Drag to reorder exercises")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appAccent)
                .textCase(nil)
        }
        .listRowBackground(Color(red: 0.11, green: 0.11, blue: 0.12))
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

                    HStack(spacing: 10) {
                        IconTile(color: Color(red: 0.36, green: 0.42, blue: 0.90), size: 28) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(
                            workout.date.formatted(
                                .dateTime.weekday(.wide).month(.wide).day().year()
                            )
                        )
                        .foregroundColor(Color(.secondaryLabel))
                    }

                    if let completedAt = workout.completedAt {
                        HStack(spacing: 10) {
                            IconTile(color: Color(red: 0.95, green: 0.55, blue: 0.19), size: 28) {
                                Image(systemName: "clock")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(formattedDuration(from: workout.createdAt, to: completedAt))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                    }
                }
                .listRowBackground(Color.black)
                .listRowSeparator(.hidden)

                if isReorderingExercises {
                    reorderModeContent
                } else {
                    ForEach(groupedExerciseNames, id: \.self) { name in
                        Section {
                            exerciseTitleRow(name)

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
                            .buttonStyle(WorkoutActionButtonStyle(tint: .appAccent, prominence: .plain))
                        }
                        .listRowBackground(Color.black)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(isReorderingExercises ? .active : .inactive))
        }
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isReorderingExercises {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.selection()
                        withAnimation {
                            isReorderingExercises = false
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appAccent)
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
                .frame(width: 68, alignment: .center)

            Text("Reps")
                .frame(width: 68, alignment: .center)

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
        Haptics.impact(.medium)
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
        Haptics.impact(.medium)
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
