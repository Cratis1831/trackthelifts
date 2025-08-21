//
//  WorkoutView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI
import SwiftData

struct WorkoutTemplate: Identifiable {
    let id = UUID()
    let name: String
    let exercises: String
}

struct WorkoutView: View {
    @Query(sort: \Workout.updatedAt, order: .reverse) private var workouts: [Workout]
    @Environment(\.modelContext) private var modelContext
    @State private var isCreateWorkoutPresented: Bool = false
    @State private var sortBy: SortOption = .name
    @State private var resumingWorkout: Workout? = nil
    
    private let sessionManager = WorkoutSessionManager.shared
    
    private var activeWorkout: Workout? {
        sessionManager.getActiveWorkout(from: modelContext)
    }
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case recent = "Recent"
    }
    
    // Sample workout templates - replace with actual data source
    private let workoutTemplates: [WorkoutTemplate] = [
        WorkoutTemplate(
            name: "Push 2025",
            exercises: "Bench Press (Barbell), Incline Bench Press (Dumbbell), Seated Overhead Press (Dumbbell), Lateral..."
        ),
        WorkoutTemplate(
            name: "Upper A - 2025",
            exercises: "Bench Press (Barbell), Pull Up (Band), Bent Over Row (Barbell), Seated Overhead Pr..."
        ),
        WorkoutTemplate(
            name: "Lower A - 2025",
            exercises: "Goblet Squat (Kettlebell) and Romanian Deadlift (Dumbbell)"
        ),
        WorkoutTemplate(
            name: "Lower A 2025 Machines",
            exercises: "Leg Extension (Machine), Seated Leg Curl (Machine), Seated Leg Press (M..."
        ),
        WorkoutTemplate(
            name: "Early Morning Workout",
            exercises: "Bench Press (Barbell), Bent Over Row"
        ),
        WorkoutTemplate(
            name: "Upper A",
            exercises: "Lat Pulldown (Cable), Incline Bench Press (Barbell), Seated Row"
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // Resume Workout Banner
                        if let activeWorkout = activeWorkout, sessionManager.isWorkoutMinimized {
                            ResumeWorkoutBanner(workout: activeWorkout) {
                                resumingWorkout = activeWorkout
                                sessionManager.resumeWorkout()
                                isCreateWorkoutPresented = true
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        
                        // Templates Section
                        VStack(alignment: .leading, spacing: 20) {
                            // Templates Header
                            HStack {
                                Text("Routines")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Add template action
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16))
                                        Text("Add Routine")
                                            .font(.system(size: 16))
                                    }
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                                    .cornerRadius(8)
                                }
                            }
                            
                            // My Templates Header
                            HStack {
                                Text("My Routines (\(workoutTemplates.count))")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Menu {
                                    Button(action: { sortBy = .name }) {
                                        Label("Sort by Name", systemImage: "textformat")
                                    }
                                    
                                    Button(action: { sortBy = .recent }) {
                                        Label("Sort by Recent", systemImage: "clock")
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        // Create folder action
                                    }) {
                                        Label("Create Folder", systemImage: "folder.badge.plus")
                                    }
                                    
                                    Button(action: {
                                        // Import template action
                                    }) {
                                        Label("Import Template", systemImage: "square.and.arrow.down")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive, action: {
                                        // Export all templates action
                                    }) {
                                        Label("Export All Templates", systemImage: "square.and.arrow.up")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 20))
                                }
                            }
                            
                            // Template Cards
                            LazyVStack(spacing: 15) {
                                ForEach(workoutTemplates) { template in
                                    TemplateCard(template: template)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 100) // Space for floating action button
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if sessionManager.isWorkoutMinimized {
                                resumingWorkout = activeWorkout
                                sessionManager.resumeWorkout()
                            } else {
                                resumingWorkout = nil
                            }
                            isCreateWorkoutPresented = true
                        }) {
                            Image(systemName: sessionManager.isWorkoutMinimized ? "play.fill" : "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(sessionManager.isWorkoutMinimized ? Color.green : Color.orange)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Workouts")
        }
        .fullScreenCover(isPresented: $isCreateWorkoutPresented, onDismiss: {
            resumingWorkout = nil
        }) {
            CreateWorkoutView(existingWorkout: resumingWorkout)
        }
    }
}

struct TemplateCard: View {
    let template: WorkoutTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Menu {
                    Button("Edit Template") {
                        // Edit action
                    }
                    Button("Duplicate Template") {
                        // Duplicate action
                    }
                    Button("Share Template") {
                        // Share action
                    }
                    Divider()
                    Button("Delete Template", role: .destructive) {
                        // Delete action
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
            }
            
            Text(template.exercises)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
        )
    }
}

struct ResumeWorkoutBanner: View {
    let workout: Workout
    let onResume: () -> Void
    
    private var completedSets: Int {
        workout.exerciseSets.filter { $0.isCompleted }.count
    }
    
    private var totalSets: Int {
        workout.exerciseSets.count
    }
    
    private var uniqueExercises: Int {
        Set(workout.exerciseSets.map { $0.exercise.name }).count
    }
    
    var body: some View {
        Button(action: onResume) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "play.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        
                        Text("Resume Workout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(workout.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(completedSets)/\(totalSets) sets • \(uniqueExercises) exercises")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                    .font(.system(size: 14))
            }
            .padding(16)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    WorkoutView()
        .modelContainer(for: [Workout.self, Exercise.self, ExerciseSet.self])
}
