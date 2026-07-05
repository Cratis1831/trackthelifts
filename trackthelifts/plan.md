# Fitness Tracker App Plan - Expo SDK 57

## Goal

Build an iterative fitness tracker app using Expo SDK 57. Start with a strong local-first workout tracker, then add templates, progress analytics, sync, health integrations, and coaching features.

## Product Scope

### Initial Product Direction

- Strength-focused workout tracker
- Manual workout logging
- Workout history
- Exercise progress tracking
- Local-first data storage
- Optional account/sync added later

### MVP User Outcomes

- User can create and complete a workout.
- User can add exercises to a workout.
- User can log sets, reps, weight, duration, and notes.
- User can view previous workouts.
- User can track basic progress over time.

## Technology Stack

### Core

- Expo SDK 57
- React Native
- TypeScript
- Expo Router

### State and Data

- Zustand for lightweight UI/application state
- `expo-sqlite` for local structured storage
- Optional Drizzle ORM or a typed repository layer
- Zod for schema validation

### Forms

- React Hook Form
- Zod validation

### UI

- React Native components
- Expo Router tabs/stacks
- `lucide-react-native` for icons
- `react-native-svg` for chart dependencies if needed

### Charts

- Confirm Expo SDK 57 compatibility before installing
- Preferred options:
  - `victory-native`
  - `react-native-gifted-charts`
  - Custom SVG charts for simple progress views

### Future Backend

- Supabase preferred for auth, Postgres, and sync
- Firebase acceptable for faster simple auth/cloud storage
- Custom backend only if product requirements justify it

### Future Health Integrations

- Apple Health
- Google Health Connect
- Add only after local workout tracking is stable

## App Structure

### Primary Navigation

- `Today`
- `Workouts`
- `Progress`
- `Profile`

### Suggested Routes

- `/`
- `/today`
- `/workouts`
- `/workouts/new`
- `/workouts/[id]`
- `/exercises`
- `/exercises/[id]`
- `/progress`
- `/profile`
- `/settings`

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

### WorkoutExercise

- `id`
- `workoutId`
- `exerciseId`
- `order`
- `notes`

### Set

- `id`
- `workoutExerciseId`
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
- `description`
- `createdAt`
- `updatedAt`

### WorkoutTemplateExercise

- `id`
- `templateId`
- `exerciseId`
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

Create the app shell, navigation, data layer, and design foundation.

### Tasks

- Initialize Expo SDK 57 app with TypeScript.
- Add Expo Router.
- Create tab navigation:
  - `Today`
  - `Workouts`
  - `Progress`
  - `Profile`
- Add base screen layouts.
- Add shared UI primitives:
  - Button
  - Text input
  - Screen container
  - List row
  - Empty state
  - Modal/sheet pattern
- Add local database setup using `expo-sqlite`.
- Add initial database schema/migrations.
- Seed common exercises.
- Add repository functions for exercises and workouts.

### Acceptance Criteria

- App launches successfully.
- Tabs navigate correctly.
- Local database initializes on first launch.
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
- Save workout locally.
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
- Add swipe or contextual actions where useful.

### Acceptance Criteria

- User can start a workout from a saved template.
- User can repeat a previous workout quickly.
- Logging repeated sets is fast.
- Personal records are detected and displayed.

## Phase 4 - Progress and Analytics

### Objective

Make user progress visible and motivating.

### Tasks

- Add `Progress` dashboard.
- Add weekly workout count.
- Add workout volume over time.
- Add exercise-specific history.
- Add estimated 1RM for weighted exercises.
- Add personal records screen.
- Add body metric tracking.
- Add body weight trend chart.
- Add calendar or weekly consistency view.

### Acceptance Criteria

- User can see recent training consistency.
- User can view progress for a specific exercise.
- User can see personal records.
- Charts render correctly on iOS and Android.

## Phase 5 - Account and Cloud Sync

### Objective

Add optional account creation, backup, and multi-device sync.

### Tasks

- Choose backend provider.
- Add auth:
  - Apple
  - Google
  - Email
- Add cloud schema matching local data model.
- Add sync queue for local changes.
- Add conflict handling strategy.
- Add backup/restore.
- Add account deletion.
- Add data export.

### Acceptance Criteria

- App remains usable without login.
- Logged-in user data syncs across devices.
- Offline workout logging still works.
- User can export and delete their data.

## Phase 6 - Health Integrations

### Objective

Connect with platform health data after core tracking is stable.

### Tasks

- Add permission screens.
- Integrate Apple Health.
- Integrate Google Health Connect.
- Read supported data:
  - Body weight
  - Steps
  - Active energy
  - Workouts
- Write supported completed workouts.
- Add manual fallback when permissions are denied.

### Acceptance Criteria

- Health permissions are optional.
- App handles denied permissions cleanly.
- Supported health data imports correctly.
- Completed workouts can be written where supported.

## Phase 7 - Coaching and Intelligence

### Objective

Add helpful recommendations based on user history.

### Tasks

- Add workout summaries.
- Add weekly training recap.
- Add suggested next workout.
- Add missed-workout recovery suggestions.
- Add deload suggestions.
- Add natural-language workout entry.
- Add exercise coaching notes.

### Acceptance Criteria

- Suggestions are based on actual logged data.
- User can accept, ignore, or modify suggestions.
- Coaching features do not block manual logging.

## Phase 8 - Release Polish

### Objective

Prepare the app for public testing and release.

### Tasks

- Add onboarding.
- Add app icon.
- Add splash screen.
- Add notification reminders.
- Add empty states.
- Add loading states.
- Add error states.
- Add accessibility labels.
- Add performance pass for long workout histories.
- Add privacy policy.
- Add app store screenshots.
- Prepare TestFlight build.
- Prepare internal Android test build.

### Acceptance Criteria

- App is stable on physical iOS and Android devices.
- Main flows work offline.
- App has clear onboarding.
- App is ready for external testers.

## Implementation Order

1. Expo SDK 57 project setup
2. Navigation and base UI
3. Local SQLite schema
4. Exercise seed data
5. Create workout flow
6. Workout detail/history
7. Templates
8. Progress dashboard
9. Optional auth/sync
10. Health integrations
11. Coaching features
12. Release polish

## Development Rules

- Keep the app local-first until the workout tracker is useful.
- Do not require login for MVP.
- Build one usable phase at a time.
- Keep data models stable before adding sync.
- Test frequently on physical devices.
- Avoid AI/coaching features until workout data is reliable.
- Keep manual logging fast and available at all times.

## First Sprint Scope

### Build

- Expo SDK 57 TypeScript app
- Expo Router tabs
- Local SQLite setup
- Exercise seed data
- `Today` screen
- `Workouts` screen
- New workout flow
- Add exercises to workout
- Add sets to exercises
- Complete workout
- Workout history

### Do Not Build Yet

- Auth
- Cloud sync
- Health integrations
- AI coaching
- Complex charts
- Social features
- Payments

### First Sprint Acceptance Criteria

- User can open the app.
- User can start a workout.
- User can add exercises.
- User can log sets.
- User can complete the workout.
- User can view the completed workout later.
- Data remains after closing and reopening the app.
