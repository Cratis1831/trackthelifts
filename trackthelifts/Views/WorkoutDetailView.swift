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

    private var groupedExerciseNames: [String] {
        Dictionary(grouping: workout.exerciseSets, by: \.exercise.name).keys.sorted()
    }

    private func sets(for exerciseName: String) -> [ExerciseSet] {
        workout.exerciseSets
            .filter { $0.exercise.name == exerciseName }
            .sorted { $0.order < $1.order }
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
                                        Label("Delete", systemImage: "trash")
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
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
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

            Text("lbs")
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
