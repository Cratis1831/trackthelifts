//
//  ExerciseData.swift
//  TrackTheLifts
//
//  Created by Claude on 2025-08-22.
//

import Foundation
import SwiftData

struct ExerciseData {
    
    // MARK: - Body Parts
    static let defaultBodyparts = [
        "Chest",
        "Back", 
        "Shoulders",
        "Biceps",
        "Triceps",
        "Forearms",
        "Quadriceps",
        "Hamstrings",
        "Glutes",
        "Calves",
        "Abs"
    ]
    
    // MARK: - Default Exercises
    static let defaultExercises: [(name: String, bodypart: String)] = [
        // Chest
        ("Barbell Bench Press", "Chest"),
        ("Incline Barbell Bench Press", "Chest"),
        ("Decline Barbell Bench Press", "Chest"),
        ("Dumbbell Bench Press", "Chest"),
        ("Incline Dumbbell Press", "Chest"),
        ("Dumbbell Flyes", "Chest"),
        ("Cable Chest Fly", "Chest"),
        ("Chest Press Machine", "Chest"),
        ("Pec Deck Machine", "Chest"),
        
        // Back
        ("Deadlift", "Back"),
        ("Barbell Row", "Back"),
        ("T-Bar Row", "Back"),
        ("Dumbbell Row", "Back"),
        ("Cable Row", "Back"),
        ("Lat Pulldown", "Back"),
        ("Pull-ups", "Back"),
        ("Cable Pullover", "Back"),
        ("Machine Row", "Back"),
        
        // Shoulders
        ("Overhead Press", "Shoulders"),
        ("Dumbbell Shoulder Press", "Shoulders"),
        ("Lateral Raises", "Shoulders"),
        ("Front Raises", "Shoulders"),
        ("Rear Delt Flyes", "Shoulders"),
        ("Cable Lateral Raises", "Shoulders"),
        ("Machine Shoulder Press", "Shoulders"),
        ("Face Pulls", "Shoulders"),
        
        // Biceps
        ("Barbell Curl", "Biceps"),
        ("Dumbbell Curl", "Biceps"),
        ("Hammer Curls", "Biceps"),
        ("Cable Bicep Curl", "Biceps"),
        ("Preacher Curls", "Biceps"),
        ("Cable Hammer Curls", "Biceps"),
        
        // Triceps
        ("Close Grip Bench Press", "Triceps"),
        ("Tricep Dips", "Triceps"),
        ("Overhead Tricep Extension", "Triceps"),
        ("Cable Tricep Pushdown", "Triceps"),
        ("Dumbbell Tricep Extension", "Triceps"),
        ("Cable Overhead Extension", "Triceps"),
        
        // Forearms
        ("Barbell Wrist Curls", "Forearms"),
        ("Dumbbell Wrist Curls", "Forearms"),
        ("Reverse Barbell Curls", "Forearms"),
        ("Cable Wrist Curls", "Forearms"),
        
        // Quadriceps
        ("Squat", "Quadriceps"),
        ("Front Squat", "Quadriceps"),
        ("Leg Press", "Quadriceps"),
        ("Bulgarian Split Squats", "Quadriceps"),
        ("Dumbbell Lunges", "Quadriceps"),
        ("Leg Extension", "Quadriceps"),
        
        // Hamstrings
        ("Romanian Deadlift", "Hamstrings"),
        ("Leg Curls", "Hamstrings"),
        ("Stiff Leg Deadlift", "Hamstrings"),
        ("Dumbbell Romanian Deadlift", "Hamstrings"),
        
        // Glutes
        ("Hip Thrust", "Glutes"),
        ("Barbell Hip Thrust", "Glutes"),
        ("Dumbbell Hip Thrust", "Glutes"),
        ("Cable Kickbacks", "Glutes"),
        
        // Calves
        ("Calf Raise", "Calves"),
        ("Seated Calf Raise", "Calves"),
        ("Dumbbell Calf Raise", "Calves"),
        ("Machine Calf Raise", "Calves"),
        
        // Abs
        ("Plank", "Abs"),
        ("Cable Crunches", "Abs"),
        ("Russian Twists", "Abs"),
        ("Machine Crunches", "Abs")
    ]
}

extension ExerciseData {
    /// Seeds the bundled exercise library once, automatically, so the app never presents an
    /// empty exercise list. Safe to call on every launch: does nothing once exercises exist.
    static func seedIfNeeded(in modelContext: ModelContext) {
        let existingExerciseCount = (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard existingExerciseCount == 0 else { return }

        let existingBodyparts = (try? modelContext.fetch(FetchDescriptor<Bodypart>())) ?? []
        var bodypartsByName = Dictionary(uniqueKeysWithValues: existingBodyparts.map { ($0.name, $0) })

        for name in defaultBodyparts where bodypartsByName[name] == nil {
            let bodypart = Bodypart(name: name)
            modelContext.insert(bodypart)
            bodypartsByName[name] = bodypart
        }

        for exerciseInfo in defaultExercises {
            let exercise = Exercise(name: exerciseInfo.name, bodypart: bodypartsByName[exerciseInfo.bodypart])
            modelContext.insert(exercise)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to seed default exercise library: \(error)")
        }
    }
}