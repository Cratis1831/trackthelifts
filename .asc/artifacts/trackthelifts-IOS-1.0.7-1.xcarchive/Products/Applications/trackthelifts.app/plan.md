# Fitness Tracker App Plan - SwiftUI and SwiftData

## Goal

Build an iterative iOS fitness tracker app using SwiftUI and SwiftData. Start with a strong local-first workout tracker, then add templates, progress analytics, iCloud sync, HealthKit integrations, and coaching features.

## Product Scope

### Initial Product Direction

- Strength-focused workout tracker
- Manual workout logging
- Workout history
- Exercise progress tracking
- Local-first data storage
- Optional iCloud sync added later

### MVP User Outcomes

- User can create and complete a workout.
- User can add exercises to a workout.
- User can log sets, reps, weight, duration, and notes.
- User can view previous workouts.
- User can track basic progress over time.

## Technology Stack

### Core

- Swift
- SwiftUI
- SwiftData
- iOS native app

### State and Data

- SwiftData for local persistence
- `@Model` types for app entities
- `@Query` for view-level data fetching
- `@Environment(\.modelContext)` for writes
- `@Observable` or `@State` for view state
- `@AppStorage` for small settings

### Navigation

- `TabView` for primary navigation
- `NavigationStack` for screen flows
- `NavigationPath` if deep navigation becomes complex
- `.sheet` and `.confirmationDialog` for modal actions

### UI

- Native SwiftUI components
- SF Symbols for icons
- Dynamic Type support
- Light and dark mode support
- Haptics for key actions where useful

### Charts

- Swift Charts
- Use simple chart views first:
  - Workout count by week
  - Volume over time
  - Exercise progress
  - Body weight trend

### Future Sync

- SwiftData with CloudKit or a custom CloudKit sync approach
- Keep sync optional until local tracking is stable

### Future Health Integrations

- HealthKit
- Add only after local workout tracking is stable

## App Structure

### Primary Tabs

- `Today`
- `Workouts`
- `Progress`
- `Profile`

### Suggested Screens

- `TodayView`
- `WorkoutListView`
- `WorkoutDetailView`
- `NewWorkoutView`
- `ExerciseListView`
- `ExerciseDetailView`
- `ProgressDashboardView`
- `ProfileView`
- `SettingsView`

### Suggested Folders

- `App`
- `Models`
- `Views`
- `Views/Today`
- `Views/Workouts`
- `Views/Exercises`
- `Views/Progress`
- `Views/Profile`
- `Components`
- `Services`
- `Utilities`
- `Resources`

## Core Data Models

### Exercise

- `id`
- `name`
- `category`
- `primaryMuscleGroup`
- `secondaryMuscleGroups`
- `equipment`
- `isCustom`
- `createdAt`
- `updatedAt`

### Workout

- `id`
- `name`
- `startedAt`
- `completedAt`
- `notes`
- `source`
- `createdAt`
- `updatedAt`
- Relationship to workout exercises

### WorkoutExercise

- `id`
- Relationship to workout
- Relationship to exercise
- `order`
- `notes`
- Relationship to sets

### WorkoutSet

- `id`
- Relationship to workout exercise
- `order`
- `type`
- `reps`
- `weight`
- `durationSeconds`
- `distance`
- `isCompleted`
- `notes`

### WorkoutTemplate

- `id`
- `name`
- `templateDescription`
- `createdAt`
- `updatedAt`
- Relationship to template exercises

### WorkoutTemplateExercise

- `id`
- Relationship to template
- Relationship to exercise
- `order`
- `targetSets`
- `targetReps`
- `targetWeight`
- `targetDurationSeconds`

### BodyMetric

- `id`
- `type`
- `value`
- `unit`
- `recordedAt`

### Goal

- `id`
- `type`
- `targetValue`
- `currentValue`
- `unit`
- `deadline`
- `status`

## Phase 1 - Project Foundation

### Objective

Create the app shell, navigation, SwiftData model layer, and design foundation.

### Tasks

- Create iOS SwiftUI project.
- Configure SwiftData model container.
- Add `TabView` navigation:
  - `Today`
  - `Workouts`
  - `Progress`
  - `Profile`
- Add `NavigationStack` inside each tab.
- Create base screen layouts.
- Add shared UI components:
  - Primary button
  - Secondary button
  - Text field row
  - Empty state
  - List row
  - Metric card
  - Section header
- Create SwiftData models.
- Add preview/mock data helpers.
- Seed common exercises on first launch.
- Add basic repository/service functions if needed.

### Acceptance Criteria

- App launches successfully.
- Tabs navigate correctly.
- SwiftData model container initializes.
- Seed exercises are available.
- No login required.

## Phase 2 - Manual Workout MVP

### Objective

Build the first usable workout tracking experience.

### Tasks

- Create new workout flow.
- Add exercise search/select.
- Add selected exercises to workout.
- Add/edit/delete sets.
- Support set fields:
  - Reps
  - Weight
  - Duration
  - Distance
  - Notes
- Mark sets completed.
- Complete workout.
- Save workout with SwiftData.
- View workout detail.
- View workout history.
- Edit/delete existing workout.

### Acceptance Criteria

- User can start and finish a workout.
- User can log multiple exercises and sets.
- Completed workouts persist after app restart.
- Workout history shows saved workouts.
- Workout detail shows exercises and sets correctly.

## Phase 3 - Templates and Fast Logging

### Objective

Reduce workout logging friction.

### Tasks

- Save completed workout as template.
- Create workout from template.
- Duplicate previous workout.
- Add recent exercises section.
- Add rest timer.
- Add personal record detection.
- Add quick-add set behavior.
- Add swipe actions for common list actions.
- Add contextual menus where useful.

### Acceptance Criteria

- User can start a workout from a saved template.
- User can repeat a previous workout quickly.
- Logging repeated sets is fast.
- Personal records are detected and displayed.

## Phase 4 - Progress and Analytics

### Objective

Make user progress visible and motivating.

### Tasks

- Add `ProgressDashboardView`.
- Add weekly workout count.
- Add workout volume over time.
- Add exercise-specific history.
- Add estimated 1RM for weighted exercises.
- Add personal records screen.
- Add body metric tracking.
- Add body weight trend chart.
- Add calendar or weekly consistency view.
- Use Swift Charts for visualizations.

### Acceptance Criteria

- User can see recent training consistency.
- User can view progress for a specific exercise.
- User can see personal records.
- Charts render correctly in light and dark mode.

## Phase 5 - iCloud Sync

### Objective

Add optional backup and multi-device sync.

### Tasks

- Confirm SwiftData and CloudKit sync approach.
- Configure iCloud capability.
- Configure CloudKit container.
- Update models for sync compatibility.
- Add sync status UI.
- Add conflict handling strategy.
- Add backup/restore expectations.
- Add account/data deletion guidance if cloud data is used.

### Acceptance Criteria

- App remains usable without explicit account setup.
- User data syncs across devices signed into the same Apple ID.
- Offline workout logging still works.
- Sync failures are handled gracefully.

## Phase 6 - HealthKit Integration

### Objective

Connect with Apple Health after core tracking is stable.

### Tasks

- Add HealthKit capability.
- Add HealthKit permission screen.
- Request only needed permissions.
- Read supported data:
  - Body mass
  - Steps
  - Active energy
  - Workouts
- Write supported completed workouts.
- Add manual fallback when permissions are denied.
- Add privacy text explaining HealthKit usage.

### Acceptance Criteria

- Health permissions are optional.
- App handles denied permissions cleanly.
- Supported health data imports correctly.
- Completed workouts can be written to Apple Health where supported.

## Phase 7 - Coaching and Intelligence

### Objective

Add helpful recommendations based on user history.

### Tasks

- Add workout summaries.
- Add weekly training recap.
- Add suggested next workout.
- Add missed-workout recovery suggestions.
- Add deload suggestions.
- Add natural-language workout entry if desired.
- Add exercise coaching notes.

### Acceptance Criteria

- Suggestions are based on actual logged data.
- User can accept, ignore, or modify suggestions.
- Coaching features do not block manual logging.

## Phase 8 - Release Polish

### Objective

Prepare the app for public testing and App Store release.

### Tasks

- Add onboarding.
- Add app icon.
- Add launch screen.
- Add notification reminders.
- Add empty states.
- Add loading states.
- Add error states.
- Add accessibility labels.
- Add Dynamic Type pass.
- Add VoiceOver pass.
- Add performance pass for long workout histories.
- Add privacy policy.
- Add App Store screenshots.
- Prepare TestFlight build.

### Acceptance Criteria

- App is stable on physical iPhone devices.
- Main flows work offline.
- App has clear onboarding.
- App passes basic accessibility checks.
- App is ready for external testers.

## Implementation Order

1. SwiftUI project setup
2. SwiftData model container
3. Navigation and base UI
4. Exercise seed data
5. Create workout flow
6. Workout detail/history
7. Templates
8. Progress dashboard
9. Optional iCloud sync
10. HealthKit integration
11. Coaching features
12. Release polish

## Development Rules

- Keep the app local-first until the workout tracker is useful.
- Do not require sign-in for MVP.
- Build one usable phase at a time.
- Keep data models stable before adding iCloud sync.
- Test frequently on physical devices.
- Avoid coaching features until workout data is reliable.
- Keep manual logging fast and available at all times.
- Prefer native SwiftUI patterns over custom UI complexity.
- Use SwiftData relationships carefully and test persistence after app relaunch.

## First Sprint Scope

### Build

- SwiftUI iOS app
- `TabView` navigation
- `NavigationStack` per tab
- SwiftData setup
- Exercise seed data
- `TodayView`
- `WorkoutListView`
- `NewWorkoutView`
- Add exercises to workout
- Add sets to exercises
- Complete workout
- Workout history

### Do Not Build Yet

- iCloud sync
- HealthKit
- AI coaching
- Complex charts
- Social features
- Payments
- Apple Watch app

### First Sprint Acceptance Criteria

- User can open the app.
- User can start a workout.
- User can add exercises.
- User can log sets.
- User can complete the workout.
- User can view the completed workout later.
- Data remains after closing and reopening the app.
