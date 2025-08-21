# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Track The Lifts is an iOS fitness tracking app built with SwiftUI and SwiftData for local persistence. The app follows a tab-based navigation pattern and uses SwiftData's `@Model` classes for data management.

## Build and Development

This is an Xcode project that can be built using:
- **Xcode**: Open `TrackTheLifts.xcodeproj` in Xcode and build with Cmd+B
- **Simulator**: Run in iOS Simulator with Cmd+R
- **Device**: Connect iOS device and run directly
- **Command Line**: From the project root directory (`/Users/ashkan/Development/swift-projects/TrackTheLifts`), use:
  ```bash
  xcodebuild -scheme TrackTheLifts -destination 'platform=iOS Simulator,name=iPhone 16' build
  ```

No external package managers (CocoaPods, SPM dependencies) are currently used.

## Architecture

### Data Models (SwiftData)
- **Workout**: Main workout entity with title, date, notes, and cascade relationship to ExerciseSet
- **Exercise**: Exercise templates (e.g., "Bench Press", "Squat") 
- **ExerciseSet**: Individual sets within a workout, linking Exercise and Workout with weight/reps data
- **Bodypart**: Body part categorization (currently minimal implementation)

All models use SwiftData's `@Model` macro and are configured in the main app's `modelContainer`.

### View Structure
- **ContentView**: Root TabView with 5 tabs (Profile, History, Create Workout, Exercises, Settings)
- **WorkoutView**: Main workout management with templates and floating action button
- **CreateWorkoutView**: Workout creation flow with exercise selection and set management
- **ExerciseListView**: Exercise selection with default exercise seeding
- **ExerciseSetView**: Individual set input component

### Key Patterns
- SwiftData relationships use `@Relationship` with cascade deletion
- Exercise selection uses closure-based callbacks between views
- Default exercises are seeded on first app launch
- Sheet presentations for modal workflows (create workout, exercise selection)

### Color Scheme
The app uses a dark theme with:
- Black background (`Color.black`)
- Orange accent color (`Color.orange`, `.tint(.orange)`)
- Dark gray cards (`Color(red: 0.11, green: 0.11, blue: 0.12)`)

## Development Notes

- The app targets iOS with SwiftUI and requires iOS 17+ for SwiftData
- Model relationships are bidirectional with proper inverse relationships
- Error handling uses do-catch blocks with console logging
- Preview providers include proper ModelContainer setup for SwiftData models