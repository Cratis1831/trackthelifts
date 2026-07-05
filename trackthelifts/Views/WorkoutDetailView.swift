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
                        .font(.system(size: 18, weight: .semibold))
                        .onChange(of: workout.title) { _, _ in
                            persistWorkoutEdit()
                        }

                    TextField(
                        "Notes",
                        text: Binding(
                            get: { workout.notes ?? "" },
                            set: { workout.notes = $0 }
                        )
                    )
                    .font(.system(size: 14))
                    .onChange(of: workout.notes) { _, _ in
                        persistWorkoutEdit()
                    }

                    if let completedAt = workout.completedAt {
                        Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                    }
                }
                .listRowBackground(Color(red: 0.11, green: 0.11, blue: 0.12))

                ForEach(groupedExerciseNames, id: \.self) { name in
                    exerciseBlock(name)
                        .listRowBackground(Color.black)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteExercise(named: name)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exerciseBlock(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Grid(horizontalSpacing: 12, verticalSpacing: 8) {
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

                ForEach(sets(for: name)) { set in
                    ExerciseSetView(exerciseSet: set)
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
        }
        .padding(.vertical, 8)
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
