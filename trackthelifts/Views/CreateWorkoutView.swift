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
    @State private var showNoCompletedSetsAlert: Bool = false
    @State private var showMarkSetsCompleteConfirmation: Bool = false
    @State private var showMissingNameAlert: Bool = false
    @State private var saveErrorMessage: String?
    @State private var prAnnouncement: String?
    @State private var pendingAutoFocusSetID: UUID?
    @State private var sessionStartDate = Date()
    @State private var isReorderingExercises = false
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
    /// Exercise names in their persisted `exerciseOrder` (drag-reorderable by the user), falling
    /// back to earliest-created-set order for older data that predates `exerciseOrder`.
    private var groupedExerciseNames: [String] {
        guard let workout = savedWorkout else { return [] }
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

    /// Reassigns sequential `exerciseOrder` values to every set after a drag-reorder, so the new
    /// order persists. Only called from reorder mode, where the ForEach is a flat one-row-per-
    /// exercise list — the sole `.onMove` configuration List supports reliably (moving multi-row
    /// Sections crashes the List's index mapping, which is why reordering collapses to compact
    /// rows first).
    private func moveExercises(from source: IndexSet, to destination: Int) {
        var names = groupedExerciseNames
        guard source.allSatisfy({ $0 < names.count }), destination <= names.count else { return }
        names.move(fromOffsets: source, toOffset: destination)

        for (index, name) in names.enumerated() {
            for set in sets(for: name) {
                set.exerciseOrder = index
            }
        }

        do {
            try modelContext.save()
            Haptics.impact(.light)
        } catch {
            print("Failed to reorder exercises: \(error)")
        }
    }

    private func sets(for exerciseName: String) -> [ExerciseSet] {
        guard let workout = savedWorkout else { return [] }
        return workout.exerciseSets
            .filter { $0.exercise.name == exerciseName }
            .sorted { $0.order < $1.order }
    }

    private func exerciseSetRow(_ exerciseSet: ExerciseSet, in workout: Workout) -> some View {
        ExerciseSetView(
            exerciseSet: exerciseSet,
            onPersonalRecord: { set, kind in
                showPersonalRecord(for: set, kind: kind)
            },
            autoFocusSetID: $pendingAutoFocusSetID
        )
        .id(exerciseSet.id)
    }

    /// Exercise name row: long-press it (or tap its grip icon) to enter reorder mode.
    private func exerciseTitleRow(_ exerciseName: String) -> some View {
        HStack {
            Text(exerciseName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            if groupedExerciseNames.count > 1 {
                Button {
                    enterReorderMode()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture {
            if groupedExerciseNames.count > 1 {
                enterReorderMode()
            }
        }
    }

    private func enterReorderMode() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Haptics.selection()
        withAnimation {
            isReorderingExercises = true
        }
    }

    /// Compact reorder mode: the workout collapses to one draggable row per exercise — the only
    /// `.onMove` configuration List supports reliably (dragging multi-row Sections crashes the
    /// List's internal index mapping). Edit mode is forced active so drag handles show instantly.
    @ViewBuilder
    private var reorderModeContent: some View {
        Section {
            ForEach(groupedExerciseNames, id: \.self) { exerciseName in
                HStack(spacing: 12) {
                    Text(exerciseName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(sets(for: exerciseName).count) set\(sets(for: exerciseName).count == 1 ? "" : "s")")
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { scrollProxy in
                    List {
                        if isReorderingExercises {
                            reorderModeContent
                        } else {
                        Section {
                            TextField("Workout Name", text: $workoutName)
                                .font(.title.bold())
                                .textFieldStyle(.plain)
                                .focused($focusWorkoutName)
                                .onChange(of: workoutName) { _, newValue in
                                    persistNameAndNotes(name: newValue, notes: workoutNotes)
                                }
                            TextField("Workout Notes", text: $workoutNotes)
                                .font(.subheadline.bold())
                                .textFieldStyle(.plain)
                                .onChange(of: workoutNotes) { _, newValue in
                                    persistNameAndNotes(name: workoutName, notes: newValue)
                                }

                            HStack(spacing: 10) {
                                IconTile(color: Color(red: 0.36, green: 0.42, blue: 0.90), size: 28) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Text(
                                    (savedWorkout?.date ?? Date()).formatted(
                                        .dateTime.weekday(.wide).month(.wide).day()
                                            .year()
                                    )
                                )
                                .foregroundColor(Color(.secondaryLabel))
                            }
                            HStack(spacing: 10) {
                                IconTile(color: Color(red: 0.95, green: 0.55, blue: 0.19), size: 28) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                TimerView(startDate: savedWorkout?.createdAt ?? sessionStartDate)
                            }

                            RestTimerBanner()
                        }
                        .listRowBackground(Color.black)
                        .listRowSeparator(.hidden)

                        if let workout = savedWorkout, !workout.exerciseSets.isEmpty {
                            ForEach(groupedExerciseNames, id: \.self) { exerciseName in
                                Section {
                                    exerciseTitleRow(exerciseName)

                                    columnHeader

                                    ForEach(sets(for: exerciseName)) { exerciseSet in
                                        exerciseSetRow(exerciseSet, in: workout)
                                            .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                deleteSet(exerciseSet, from: workout)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                        }
                                    }

                                    Button {
                                        addNewSet(for: sets(for: exerciseName).first?.exercise, to: workout)
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
                        } else {
                            Section {
                                Text("Tap the + button to add your first exercise.")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                            .listRowBackground(Color.black)
                            .listRowSeparator(.hidden)
                        }

                        Section {
                            Button {
                                showCancelConfirmation = true
                            } label: {
                                Text("Cancel Workout")
                            }
                            .buttonStyle(WorkoutActionButtonStyle(tint: .red, prominence: .plain))
                        }
                        .listRowBackground(Color.black)
                        .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(isReorderingExercises ? .active : .inactive))
                    .onChange(of: pendingAutoFocusSetID) { _, newValue in
                        guard let newValue else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation {
                                scrollProxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !isReorderingExercises {
                    Button {
                        showExerciseList.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.appAccent)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 70)
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
                        let nextExerciseOrder = (workout.exerciseSets.map(\.exerciseOrder).max() ?? -1) + 1
                        let newExerciseSet = ExerciseSet(
                            weight: 0,
                            reps: 0,
                            order: workout.exerciseSets.filter { $0.exercise == selectedTemplate }.count,
                            exerciseOrder: nextExerciseOrder,
                            exercise: selectedTemplate,
                            workout: workout
                        )
                        workout.exerciseSets.append(newExerciseSet)
                        modelContext.insert(newExerciseSet)

                        do {
                            try modelContext.save()
                            pendingAutoFocusSetID = newExerciseSet.id
                        } catch {
                            print("Failed to save exercise: \(error.localizedDescription)")
                        }
                    }

                    showExerciseList = false
                })
            }

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
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            minimizeWorkout()
                        } label: {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.primary)
                                .font(.headline)
                                .frame(width: 36, height: 36)
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            attemptFinishWorkout()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .alert("Cancel Workout", isPresented: $showCancelConfirmation) {
                Button("No", role: .cancel) { }
                Button("Yes", role: .destructive) {
                    cancelWorkout()
                }
            } message: {
                Text("Are you sure you want to cancel this workout? Any unsaved changes will be lost.")
            }
            .alert("Workout Name Required", isPresented: $showMissingNameAlert) {
                Button("OK") { }
            } message: {
                Text("Give this workout a name before finishing it.")
            }
            .alert("No Sets Completed", isPresented: $showNoCompletedSetsAlert) {
                Button("OK") { }
            } message: {
                Text("Log and check off at least one set before finishing this workout.")
            }
            .alert("Finish Workout?", isPresented: $showMarkSetsCompleteConfirmation) {
                Button("Go Back", role: .cancel) { }
                Button("Mark Complete & Finish") {
                    markLoggedSetsCompleteAndFinish()
                }
            } message: {
                Text("You've logged weight and reps but haven't checked any sets off yet. Completed sets are required to finish — mark your logged sets as complete and finish the workout?")
            }
            .alert("Couldn't Save", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK") { }
            } message: {
                Text(saveErrorMessage ?? "Something went wrong. Please try again.")
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
        let label: String
        switch kind {
        case .weight: label = "New weight PR!"
        case .estimated1RM: label = "New estimated 1RM PR!"
        case .volume: label = "New volume PR!"
        }
        Haptics.success()
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
                saveErrorMessage = "Your workout couldn't be saved. Please try again."
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
            saveErrorMessage = "Your workout couldn't be saved. Please try again."
        }
    }
    
    /// Keeps the persisted workout's title/notes in sync with the text fields as the user types,
    /// so edits made after the first exercise is added aren't lost if the user finishes the
    /// workout without minimizing it first.
    private func persistNameAndNotes(name: String, notes: String) {
        guard let workout = savedWorkout else { return }
        workout.title = name
        workout.notes = notes
        workout.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            print("Failed to persist workout name/notes: \(error)")
            saveErrorMessage = "Your workout name/notes couldn't be saved. Please try again."
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

    private func attemptFinishWorkout() {
        guard let workout = savedWorkout else { return }

        if workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showMissingNameAlert = true
            return
        }

        let loggedSets = workout.exerciseSets.filter { $0.reps > 0 }
        if loggedSets.isEmpty {
            showNoCompletedSetsAlert = true
            return
        }

        let hasIncompleteLoggedSet = loggedSets.contains { !$0.isCompleted }
        if hasIncompleteLoggedSet {
            showMarkSetsCompleteConfirmation = true
        } else {
            finishWorkout()
        }
    }

    private func markLoggedSetsCompleteAndFinish() {
        guard let workout = savedWorkout else { return }

        for set in workout.exerciseSets where set.reps > 0 {
            set.isCompleted = true
            set.updatedAt = .now
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to mark sets complete: \(error)")
            saveErrorMessage = "Some sets couldn't be marked complete. Please try again."
            return
        }

        finishWorkout()
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
            Haptics.success()
            dismiss()
        } catch {
            print("Failed to complete workout: \(error)")
            saveErrorMessage = "Your workout couldn't be finished. Please try again."
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
            exerciseOrder: lastSet?.exerciseOrder ?? 0,
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

    /// Removes a set and renumbers the remaining sets for that exercise so "Set N" stays sequential.
    private func deleteSet(_ set: ExerciseSet, from workout: Workout) {
        let exercise = set.exercise
        workout.exerciseSets.removeAll { $0.id == set.id }
        modelContext.delete(set)

        let remaining = workout.exerciseSets
            .filter { $0.exercise.id == exercise.id }
            .sorted { $0.order < $1.order }
        for (index, remainingSet) in remaining.enumerated() {
            remainingSet.order = index
        }

        do {
            try modelContext.save()
            Haptics.impact(.medium)
        } catch {
            print("Failed to delete set: \(error)")
        }
    }
}

/// Shared visual style for the primary workout-flow actions (Add Set, Add Exercise, Finish Workout).
/// `.filled` is for the main calls to action, `.tinted` is a bordered secondary style, and `.plain`
/// is bare icon+text with no background/border at all (for frequent, low-stakes repeated actions).
struct WorkoutActionButtonStyle: ButtonStyle {
    enum Prominence {
        case filled
        case tinted
        case plain
    }

    let tint: Color
    var prominence: Prominence = .filled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(prominence == .filled ? Color.white : tint)
            .frame(maxWidth: .infinity, minHeight: prominence == .plain ? 44 : 50)
            .background {
                if prominence == .filled {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint)
                } else if prominence == .tinted {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.15))
                }
            }
            .overlay {
                if prominence == .tinted {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.4), lineWidth: 1)
                }
            }
            .shadow(color: prominence == .filled ? tint.opacity(0.35) : .clear, radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
                IconTile(color: Color(red: 0.95, green: 0.55, blue: 0.19), size: 28) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("Rest: \(formattedTime(remainingSeconds))")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                HStack(spacing: 20) {
                    Button("+15s") {
                        manager.addTime(15)
                    }
                    .font(.system(size: 13, weight: .medium))
                    Button("Skip") {
                        manager.cancel()
                    }
                    .font(.system(size: 13, weight: .medium))
                }
            }
            .padding(10)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .cornerRadius(10)
            .onReceive(ticker) { value in
                // Fire the rest-over haptic exactly on the tick where the countdown crosses zero.
                // A manual Skip nils endDate first, making wasPositive false, so skips stay silent.
                let wasPositive = remainingSeconds > 0
                now = value
                if wasPositive && remainingSeconds <= 0 {
                    Haptics.restTimerComplete()
                    SoundEffects.restTimerChime()
                    manager.clearPendingNotification()
                }
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
