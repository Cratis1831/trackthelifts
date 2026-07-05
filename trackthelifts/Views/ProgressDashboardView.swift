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

    private var weeklyCounts: [ProgressStatsService.WeeklyCount] {
        ProgressStatsService.weeklyWorkoutCounts(in: modelContext)
    }

    private var volumePoints: [ProgressStatsService.WorkoutVolumePoint] {
        ProgressStatsService.volumeOverTime(in: modelContext)
    }

    private var records: [ProgressStatsService.ExercisePersonalRecord] {
        ProgressStatsService.personalRecords(in: modelContext)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if completedWorkouts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            consistencySection
                            weeklyCountSection
                            volumeSection
                            personalRecordsSection
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Progress")
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseProgressView(exercise: exercise)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))

            Text("No Progress Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Complete your first workout to start seeing trends here.")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Consistency", subtitle: "Last \(weeklyCounts.count) weeks")

            HStack(spacing: 6) {
                ForEach(weeklyCounts) { week in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(week.count > 0 ? Color.orange : Color(red: 0.17, green: 0.17, blue: 0.18))
                        .frame(height: 28)
                }
            }
        }
    }

    private var weeklyCountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Weekly Workouts", subtitle: nil)

            Chart(weeklyCounts) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Workouts", week.count)
                )
                .foregroundStyle(Color.orange)
                .cornerRadius(4)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Volume Over Time", subtitle: "Weight \u{00D7} reps per workout")

            if volumePoints.isEmpty {
                Text("No completed sets yet.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            } else {
                Chart(volumePoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(Color.orange)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(Color.orange)
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Personal Records", subtitle: nil)

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

                Text("Best: \(formattedWeight(record.bestWeight)) \u{00D7} \(record.bestWeightReps)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("~\(formattedWeight(record.best1RM))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
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

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            }
        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(weight)) : String(format: "%.1f", weight)
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self, ExerciseSet.self,
            WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
