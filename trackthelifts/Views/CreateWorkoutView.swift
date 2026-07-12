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
    @State private var completionSummary: WorkoutCompletionSummary?
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
    /// The workout's sets grouped per exercise (sets sorted by set order), in the persisted
    /// `exerciseOrder` (drag-reorderable by the user), falling back to earliest-created-set order
    /// for older data that predates `exerciseOrder`. `body` computes this once per render and
    /// passes the groups down, instead of re-grouping/re-sorting per exercise row.
    private var exerciseGroups: [(name: String, sets: [ExerciseSet])] {
        guard let workout = savedWorkout else { return [] }
        let grouped = Dictionary(grouping: workout.exerciseSets, by: \.exercise.name)
        return grouped
            .map { (name: $0.key, sets: $0.value.sorted { $0.order < $1.order }) }
            .sorted { lhs, rhs in
                let order1 = lhs.sets.map(\.exerciseOrder).min() ?? Int.max
                let order2 = rhs.sets.map(\.exerciseOrder).min() ?? Int.max
                if order1 != order2 { return order1 < order2 }
                let earliest1 = lhs.sets.map(\.createdAt).min() ?? .distantFuture
                let earliest2 = rhs.sets.map(\.createdAt).min() ?? .distantFuture
                return earliest1 < earliest2
            }
    }

    private var exerciseBlocks: [[(name: String, sets: [ExerciseSet])]] {
        let groups = exerciseGroups
        var blocks: [[(name: String, sets: [ExerciseSet])]] = []
        var index = 0
        while index < groups.count {
            let group = groups[index]
            if let supersetID = group.sets.first?.supersetGroupID,
               index + 1 < groups.count,
               groups[index + 1].sets.first?.supersetGroupID == supersetID {
                blocks.append([group, groups[index + 1]])
                index += 2
            } else {
                blocks.append([group])
                index += 1
            }
        }
        return blocks
    }

    /// Reassigns sequential `exerciseOrder` values to every set after a drag-reorder, so the new
    /// order persists. Only called from reorder mode, where the ForEach is a flat one-row-per-
    /// exercise list — the sole `.onMove` configuration List supports reliably (moving multi-row
    /// Sections crashes the List's index mapping, which is why reordering collapses to compact
    /// rows first).
    private func moveExerciseBlocks(from source: IndexSet, to destination: Int) {
        var blocks = exerciseBlocks
        guard source.allSatisfy({ $0 < blocks.count }), destination <= blocks.count else { return }
        blocks.move(fromOffsets: source, toOffset: destination)

        for (index, group) in blocks.flatMap({ $0 }).enumerated() {
            for set in group.sets {
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
    private func exerciseTitleRow(
        _ exerciseName: String,
        groups: [(name: String, sets: [ExerciseSet])],
        canReorder: Bool
    ) -> some View {
        HStack {
            if let position = supersetPosition(for: exerciseName, in: groups) {
                Text("A\(position)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.onAppAccent)
                    .frame(width: 24, height: 24)
                    .background(Color.appAccent)
                    .clipShape(Circle())
            }

            Text(exerciseName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            if savedWorkout?.supersetID(for: exerciseName) != nil {
                Text("SUPERSET")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.appAccent)
            }

            if groups.count > 1 {
                Menu {
                    supersetMenu(for: exerciseName, in: groups)
                } label: {
                    Image(systemName: savedWorkout?.supersetID(for: exerciseName) == nil ? "link" : "link.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(savedWorkout?.supersetID(for: exerciseName) == nil ? .appTextSecondary : .appAccent)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            if canReorder {
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
            if canReorder {
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
    private func reorderModeContent(blocks: [[(name: String, sets: [ExerciseSet])]]) -> some View {
        Section {
            ForEach(blocks, id: \.first!.name) { block in
                HStack(spacing: 12) {
                    Text(block.map(\.name).joined(separator: " + "))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(block.count == 2 ? "Superset" : "\(block[0].sets.count) sets")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .padding(.vertical, 4)
            }
            .onMove(perform: moveExerciseBlocks)
        } header: {
            Text("Drag to reorder exercises")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appAccent)
                .textCase(nil)
        }
        .listRowBackground(Color.appSurface)
    }

    private func supersetPosition(
        for exerciseName: String,
        in groups: [(name: String, sets: [ExerciseSet])]
    ) -> Int? {
        guard let index = groups.firstIndex(where: { $0.name == exerciseName }),
              let groupID = groups[index].sets.first?.supersetGroupID else { return nil }
        let members = groups.indices.filter { groups[$0].sets.first?.supersetGroupID == groupID }
        guard let memberIndex = members.firstIndex(of: index) else { return nil }
        return memberIndex + 1
    }

    @ViewBuilder
    private func supersetMenu(
        for exerciseName: String,
        in groups: [(name: String, sets: [ExerciseSet])]
    ) -> some View {
        if let workout = savedWorkout,
           let index = groups.firstIndex(where: { $0.name == exerciseName }) {
            if workout.supersetID(for: exerciseName) != nil {
                Button("Remove Superset", role: .destructive) {
                    workout.removeSuperset(containing: exerciseName)
                    persistSupersetChange()
                }
            } else {
                if index > 0, workout.supersetID(for: groups[index - 1].name) == nil {
                    Button("Pair with \(groups[index - 1].name)") {
                        workout.setSuperset(groups[index - 1].name, exerciseName)
                        persistSupersetChange()
                    }
                }
                if index + 1 < groups.count, workout.supersetID(for: groups[index + 1].name) == nil {
                    Button("Pair with \(groups[index + 1].name)") {
                        workout.setSuperset(exerciseName, groups[index + 1].name)
                        persistSupersetChange()
                    }
                }
            }
        }
    }

    private func persistSupersetChange() {
        do {
            try modelContext.save()
            Haptics.selection()
        } catch {
            print("Failed to update superset: \(error)")
        }
    }

    private func rowBackground(for group: (name: String, sets: [ExerciseSet])) -> some View {
        ZStack(alignment: .leading) {
            Color.appCanvas
            if group.sets.first?.supersetGroupID != nil {
                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: 3)
            }
        }
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
                Color.appCanvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { scrollProxy in
                    List {
                        // Grouping walks and sorts every set, so compute it once per render here
                        // and hand the result down instead of re-deriving it per exercise row.
                        let groups = exerciseGroups
                        if isReorderingExercises {
                            reorderModeContent(blocks: exerciseBlocks)
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
                                        .foregroundColor(.appTextPrimary)
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
                                        .foregroundColor(.appTextPrimary)
                                }
                                TimerView(startDate: savedWorkout?.createdAt ?? sessionStartDate)
                            }
                        }
                        .listRowBackground(Color.appCanvas)
                        .listRowSeparator(.hidden)

                        if let workout = savedWorkout, !groups.isEmpty {
                            ForEach(groups, id: \.name) { group in
                                Section {
                                    RestTimerBanner(exerciseName: group.name)

                                    exerciseTitleRow(group.name, groups: groups, canReorder: groups.count > 1)

                                    ExerciseNoteField(workout: workout, exerciseName: group.name)

                                    columnHeader

                                    ForEach(group.sets) { exerciseSet in
                                        exerciseSetRow(exerciseSet, in: workout)
                                            .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                deleteSet(exerciseSet, from: workout)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .tint(.red)
                                        }
                                    }

                                    Button {
                                        addNewSet(for: group.sets.first?.exercise, to: workout)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus")
                                            Text("Add Set")
                                        }
                                    }
                                    .buttonStyle(WorkoutActionButtonStyle(tint: .appAccent, prominence: .plain))
                                }
                                .listRowBackground(rowBackground(for: group))
                                .listRowSeparator(.hidden)
                            }
                        } else {
                            Section {
                                Text("Tap the + button to add your first exercise.")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                            .listRowBackground(Color.appCanvas)
                            .listRowSeparator(.hidden)
                        }

                        Section {
                            Button {
                                showExerciseList.toggle()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("Add Exercise")
                                }
                            }
                            .buttonStyle(WorkoutActionButtonStyle(tint: .appAccent, prominence: .plain))

                            Button {
                                showCancelConfirmation = true
                            } label: {
                                Text("Cancel Workout")
                            }
                            .buttonStyle(WorkoutActionButtonStyle(tint: .red, prominence: .plain))
                        }
                        .listRowBackground(Color.appCanvas)
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
                                .foregroundColor(.appTextPrimary)
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
        .overlay {
            if let completionSummary {
                WorkoutCompletionView(summary: completionSummary) {
                    dismiss()
                }
                .zIndex(100)
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
        // Canceling discards the whole workout ("any unsaved changes will be lost"), so delete it
        // regardless of whether any sets were logged — its ExerciseSets cascade away with it. The
        // guard here previously only fired for empty workouts, which left a workout that had sets
        // persisted as `isActive` with `activeWorkoutID` still pointing at it: the session never
        // ended, so "Workout In Progress" kept blocking new workouts even after canceling.
        if let workout = savedWorkout {
            modelContext.delete(workout)
            try? modelContext.save()
        }
        sessionManager.completeWorkout()
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
            withAnimation(.easeOut(duration: 0.22)) {
                completionSummary = WorkoutCompletionSummary(workout: workout)
            }
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
            workout: workout,
            supersetGroupID: lastSet?.supersetGroupID
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
        workout.preserveExerciseNote(beforeDeleting: set)
        workout.exerciseSets.removeAll { $0.id == set.id }
        modelContext.delete(set)

        let remaining = workout.exerciseSets
            .filter { $0.exercise.id == exercise.id }
            .sorted { $0.order < $1.order }
        for (index, remainingSet) in remaining.enumerated() {
            remainingSet.order = index
        }
        workout.normalizeSupersets()

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
            .foregroundStyle(prominence == .filled ? Color.onAppAction : tint)
            .frame(maxWidth: .infinity, minHeight: prominence == .plain ? 44 : 50)
            .background {
                if prominence == .filled {
                    RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                        .fill(Color.appAction)
                } else if prominence == .tinted {
                    RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                        .fill(Color.appElevatedSurface)
                }
            }
            .overlay {
                if prominence == .tinted {
                    RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                        .strokeBorder(Color.appBorder, lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Optional per-exercise note field shown under the exercise title in both the active-workout
/// and history-detail screens. The note lives on one of the exercise's sets (see
/// `ExerciseSet.exerciseNote`), so all reads/writes go through the `Workout` helpers, saving on
/// every change like the workout name/notes fields do.
struct ExerciseNoteField: View {
    let workout: Workout
    let exerciseName: String

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TextField(
            "Add note",
            text: Binding(
                get: { workout.exerciseNote(for: exerciseName) },
                set: { newValue in
                    workout.setExerciseNote(newValue, for: exerciseName)
                    workout.updatedAt = .now
                    do {
                        try modelContext.save()
                    } catch {
                        print("Failed to save exercise note: \(error)")
                    }
                }
            ),
            axis: .vertical
        )
        .font(.system(size: 14))
        .textFieldStyle(.plain)
    }
}

/// Shows the rest countdown above the exercise whose set just started it, so it stays in view
/// without requiring a scroll back to the top of the workout once more exercises are added.
struct RestTimerBanner: View {
    let exerciseName: String

    private let manager = RestTimerManager.shared

    var body: some View {
        // Drive the countdown off a wall-clock schedule that re-invokes this closure every second.
        // This is what makes the banner tick down *and* remove itself the moment the timer elapses:
        // `manager.endDate` only changes when the timer is started/adjusted (not each second), so
        // without a per-second re-render the `isRunning` check below would never be re-evaluated and
        // a finished timer's banner would linger. Values are read from the live clock (see
        // `remainingSeconds`), so the very first frame is already correct — no flash. The completion
        // chime/haptic is handled app-wide by RestTimerCompletionWatcher, not here.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if manager.isRunning && manager.activeExerciseName == exerciseName {
                let remainingSeconds = max(0, Int(manager.remainingTime.rounded()))
                HStack {
                    IconTile(color: Color(red: 0.95, green: 0.55, blue: 0.19), size: 28) {
                        Image(systemName: "timer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                    }
                    Text("Rest: \(formattedTime(remainingSeconds))")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    HStack(spacing: 16) {
                        // Only offer -15s while there's more than 15s left, so the countdown can't be
                        // pulled to or below zero.
                        Button("-15s") {
                            manager.subtractTime(15)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .disabled(remainingSeconds <= 15)
                        Button("+15s") {
                            manager.addTime(15)
                        }
                        .font(.system(size: 13, weight: .medium))
                        Button("Skip") {
                            manager.cancel()
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                    // Inside a List row, default-styled buttons share one hit target, so a tap
                    // anywhere on the banner would fire one of them (e.g. Skip). Borderless gives each
                    // button its own independent tap region.
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(Color.appSurface)
                .cornerRadius(10)
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
