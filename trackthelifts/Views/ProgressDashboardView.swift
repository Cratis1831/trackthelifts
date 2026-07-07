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

    private func refreshStats() {
        weeklyCounts = ProgressStatsService.weeklyWorkoutCounts(in: modelContext)
        volume = ProgressStatsService.volumeOverTime(in: modelContext)
        records = ProgressStatsService.personalRecords(in: modelContext)
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
                .foregroundStyle(Color.appAccent)
                .cornerRadius(4)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading)
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
                Chart(volume.points) { point in
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
