//
//  HistoryView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<Workout> { workout in
            workout.completedAt != nil && !workout.isDeleted
        },
        sort: \Workout.completedAt,
        order: .reverse
    ) private var completedWorkouts: [Workout]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if completedWorkouts.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                        
                        Text("No Completed Workouts")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Your workout history will appear here once you complete your first workout.")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(completedWorkouts) { workout in
                                WorkoutHistoryCard(workout: workout)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

struct WorkoutHistoryCard: View {
    let workout: Workout
    
    private var exerciseGroups: [(String, [ExerciseSet])] {
        let grouped = Dictionary(grouping: workout.exerciseSets, by: \.exercise.name)
        return grouped.sorted { $0.key < $1.key }
    }
    
    private var totalSets: Int {
        workout.exerciseSets.count
    }
    
    private var completedSets: Int {
        workout.exerciseSets.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let completedAt = workout.completedAt {
                        Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(completedSets)/\(totalSets) sets")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Text("\(exerciseGroups.count) exercises")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                }
            }
            
            // Exercise Summary
            if !exerciseGroups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(exerciseGroups.prefix(3)), id: \.0) { exerciseName, sets in
                        HStack {
                            Text("• \(exerciseName)")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.76, green: 0.76, blue: 0.78))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(sets.count) set\(sets.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                        }
                    }
                    
                    if exerciseGroups.count > 3 {
                        Text("and \(exerciseGroups.count - 3) more...")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                            .padding(.top, 2)
                    }
                }
            }
            
            // Workout Notes (if any)
            if let notes = workout.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.66, green: 0.66, blue: 0.68))
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
        )
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseSet.self])
}
