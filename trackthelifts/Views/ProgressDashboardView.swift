//
//  ProgressDashboardView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workout> { $0.completedAt != nil && !$0.isDeleted }
    ) private var completedWorkouts: [Workout]

    // Cached in @State and recomputed on appear / when the completed-workout list changes, rather
    // than computed in `body`. Each of these backs a full SwiftData fetch plus aggregation, and
    // `body` reads them several times per render — as computed properties they re-ran the fetches
    // on every access.
    @State private var weeklyCounts: [ProgressStatsService.WeeklyCount] = []
    @State private var volume = ProgressStatsService.VolumeOverTime(granularity: .day, points: [])
    @State private var records: [ProgressStatsService.ExercisePersonalRecord] = []

    // Chart selection is split into two vars per chart: the raw date bound to `chartXSelection`
    // (which the system clears on finger lift) and a persisted snapped point that keeps the
    // callout visible after the gesture ends. Tapping the selected mark again dismisses it.
    @State private var rawSelectedWeekDate: Date?
    @State private var selectedWeek: ProgressStatsService.WeeklyCount?
    @State private var rawSelectedVolumeDate: Date?
    @State private var selectedVolumePoint: ProgressStatsService.WorkoutVolumePoint?

    private func refreshStats() {
        weeklyCounts = ProgressStatsService.weeklyWorkoutCounts(in: modelContext)
        volume = ProgressStatsService.volumeOverTime(in: modelContext)
        records = ProgressStatsService.personalRecords(in: modelContext)
        // The arrays above are rebuilt with fresh ids, so a retained selection could describe
        // data that no longer matches what's drawn.
        selectedWeek = nil
        selectedVolumePoint = nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        ProfileHeaderView(totalWorkouts: completedWorkouts.count)

                        if completedWorkouts.isEmpty {
                            emptyState
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            Text("Progress")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.top, 4)

                            consistencySection
                            weeklyCountSection
                            volumeSection
                            personalRecordsSection
                        }
                    }
                    .padding(20)
                }
                // The only text field (the profile name) sits at the very top of this scroll
                // content, so it's never covered by the keyboard. Opting out of keyboard avoidance
                // stops the keyboard from insetting — and therefore re-laying out — the charts and
                // records below it, which is what caused a hitch when tapping into the name field.
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .navigationTitle("Profile")
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseProgressView(exercise: exercise)
            }
            .onAppear(perform: refreshStats)
            .onChange(of: completedWorkouts) { _, _ in
                refreshStats()
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "chart.line.uptrend.xyaxis",
            title: "No Progress Yet",
            message: "Complete your first workout to start seeing trends here."
        )
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Consistency",
                subtitle: "Last \(weeklyCounts.count) weeks",
                info: "Each box is one week. Orange means you completed at least one workout that week; gray means you didn't."
            )

            HStack(spacing: 6) {
                ForEach(weeklyCounts) { week in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(week.count > 0 ? Color.appAccent : Color(red: 0.17, green: 0.17, blue: 0.18))
                        .frame(height: 28)
                }
            }
        }
    }

    private var weeklyCountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Weekly Workouts",
                subtitle: nil,
                info: "The number of workouts you completed in each week, so you can see how your training frequency changes over time."
            )

            Chart(weeklyCounts) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Workouts", week.count)
                )
                .foregroundStyle(
                    selectedWeek == nil || selectedWeek?.weekStart == week.weekStart
                        ? Color.appAccent
                        : Color.appAccent.opacity(0.35)
                )
                .cornerRadius(4)
                .annotation(
                    position: .top,
                    spacing: 6,
                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                ) {
                    if week.weekStart == selectedWeek?.weekStart {
                        ChartCalloutView(
                            title: "Week of \(week.weekStart.formatted(.dateTime.month(.abbreviated).day()))",
                            value: "\(week.count) workout\(week.count == 1 ? "" : "s")"
                        )
                    }
                }
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXSelection(value: $rawSelectedWeekDate)
            .animation(.easeInOut(duration: 0.15), value: selectedWeek?.weekStart)
            .onChange(of: rawSelectedWeekDate) { old, new in
                guard let new else { return }
                let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: new)?.start
                let snapped = weeklyCounts.first { $0.weekStart == weekStart }
                    ?? weeklyCounts.nearest(to: new, by: \.weekStart)
                // Compare by weekStart, not id — WeeklyCount ids are regenerated on every refresh.
                if old == nil, snapped?.weekStart == selectedWeek?.weekStart {
                    selectedWeek = nil
                } else if snapped?.weekStart != selectedWeek?.weekStart {
                    selectedWeek = snapped
                    Haptics.selection()
                }
            }
        }
    }

    private var volumeSection: some View {
        let isDaily = volume.granularity == .day
        let axisUnit: Calendar.Component = isDaily ? .day : .month

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Volume Over Time",
                subtitle: isDaily ? "Weight \u{00D7} reps per day" : "Weight \u{00D7} reps per month",
                info: "Total volume (weight \u{00D7} reps, added up across all your completed sets) summed per \(isDaily ? "day" : "month"), so you can see whether your training load is trending up over time. Once you have workouts spanning more than the current month, this switches from days to months."
            )

            if volume.points.isEmpty {
                Text("No completed sets yet.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            } else {
                Chart {
                    ForEach(volume.points) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: axisUnit),
                            y: .value("Volume", point.volume)
                        )
                        .foregroundStyle(Color.appAccent)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date, unit: axisUnit),
                            y: .value("Volume", point.volume)
                        )
                        .foregroundStyle(Color.appAccent)
                    }

                    if let sel = selectedVolumePoint {
                        RuleMark(x: .value("Date", sel.date, unit: axisUnit))
                            .foregroundStyle(Color.white.opacity(0.25))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .annotation(
                                position: .top,
                                spacing: 0,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                            ) {
                                ChartCalloutView(
                                    title: isDaily
                                        ? sel.date.formatted(.dateTime.month(.abbreviated).day())
                                        : sel.date.formatted(.dateTime.month(.wide).year()),
                                    value: "\(Int(sel.volume.rounded()).formatted()) \(WeightUnitPreference.shared.unit.label)"
                                )
                            }

                        PointMark(
                            x: .value("Date", sel.date, unit: axisUnit),
                            y: .value("Volume", sel.volume)
                        )
                        .symbolSize(120)
                        .foregroundStyle(Color.appAccent)
                    }
                }
                .frame(height: 160)
                .chartXAxis {
                    if isDaily {
                        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day())
                        }
                    } else {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXSelection(value: $rawSelectedVolumeDate)
                .onChange(of: rawSelectedVolumeDate) { old, new in
                    guard let new else { return }
                    // Mirror the marks' bucketing; fall back to nearest since points are sparse
                    // (days/months without workouts have no point).
                    let component: Calendar.Component = volume.granularity == .day ? .day : .month
                    let bucket = Calendar.current.dateInterval(of: component, for: new)?.start
                    let snapped = volume.points.first { $0.date == bucket }
                        ?? volume.points.nearest(to: new, by: \.date)
                    if old == nil, snapped?.id == selectedVolumePoint?.id {
                        selectedVolumePoint = nil
                    } else if snapped?.id != selectedVolumePoint?.id {
                        selectedVolumePoint = snapped
                        Haptics.selection()
                    }
                }
            }
        }
    }

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Personal Records",
                subtitle: nil,
                info: "Your best logged weight and estimated one-rep max (1RM) for each exercise, based on your completed sets. Tap an exercise to see its full history."
            )

            if records.isEmpty {
                Text("No personal records yet.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            } else {
                VStack(spacing: 10) {
                    ForEach(records) { record in
                        NavigationLink(value: record.exercise) {
                            recordRow(record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recordRow(_ record: ProgressStatsService.ExercisePersonalRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.exercise.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Text("Best: \(record.bestWeight.formattedWeight) \(WeightUnitPreference.shared.unit.label) \u{00D7} \(record.bestWeightReps)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("~\(record.best1RM.formattedWeight) \(WeightUnitPreference.shared.unit.label)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appAccent)
                Text("est. 1RM")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            }

            Image(systemName: "chevron.forward")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                .padding(.leading, 6)
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
        )
    }

}

/// Section title with a subtitle and a tappable info icon that explains what the section shows.
private struct SectionHeaderView: View {
    let title: String
    let subtitle: String?
    let info: String

    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfo) {
                    Text(info)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding()
                        .frame(minWidth: 240, idealWidth: 280)
                        .presentationCompactAdaptation(.popover)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            }
        }
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self, ExerciseSet.self,
            WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
