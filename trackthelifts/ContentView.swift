//
//  ContentView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI
import StoreKit
import CoreData
import Combine

struct ContentView: View {
    private enum AppTab: Hashable {
        case profile, history, createWorkout, exercises, settings
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var revenueCatService: RevenueCatService
    @State private var selectedTab: AppTab = .profile
    private var cloudSyncPreference = CloudSyncPreference.shared

    var body: some View {
        ZStack {
            appTabView
                .tint(.appAccent)
                .toolbarColorScheme(.dark, for: .tabBar)
                .toolbarBackground(Color.appSurface, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)

            // Onboarding is a plain overlay rather than a fullScreenCover: presenting a cover
            // from a computed binding during the app's very first frame can fail and write
            // `false` back through the binding, permanently marking onboarding completed before
            // a new user ever saw it.
            if !hasCompletedOnboarding {
                OnboardingView()
                    .zIndex(1)
                    .transition(.opacity)
            }

            if showsCloudSyncAnnouncement {
                cloudSyncAnnouncementCard
                    .zIndex(0.5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.3), value: hasCompletedOnboarding)
        .animation(.easeOut(duration: 0.25), value: showsCloudSyncAnnouncement)
        .watchesRestTimerCompletion()
        .onAppear {
            UIApplication.shared.enableTapToDismissKeyboard()
            ExerciseData.seedIfNeeded(in: modelContext)
            PrebuiltRoutineCatalog.seedIfNeeded(in: modelContext)
            WorkoutSessionManager.shared.reconcileOrphanedActiveWorkouts(in: modelContext)
            if CloudSyncPreference.shared.isStoreMirrored {
                CloudSyncMergeService.mergeDuplicates(in: modelContext)
            }
        }
        .onReceive(
            // CloudKit imports arrive as store-level remote changes; the seeded exercise
            // library exists on every device, so merge same-named duplicates once a batch of
            // changes settles. Debounced because the initial import fires this repeatedly.
            NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
        ) { _ in
            guard CloudSyncPreference.shared.isStoreMirrored else { return }
            CloudSyncMergeService.mergeDuplicates(in: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appReviewRequestEligible)) { _ in
            // Let the workout cover and completion celebration fully dismiss before StoreKit is
            // asked to present its prompt from this stable root view.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                requestReview()
            }
        }
    }

    @ViewBuilder
    private var appTabView: some View {
        if #available(iOS 18.0, *) {
            modernTabView
        } else {
            legacyTabView
        }
    }

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Profile", systemImage: "person", value: .profile) {
                ProfileView()
            }

            Tab("History", systemImage: "clock", value: .history) {
                HistoryView()
            }

            Tab("Create Workout", systemImage: "plus", value: .createWorkout) {
                WorkoutView()
            }

            Tab("Exercises", systemImage: "dumbbell", value: .exercises) {
                ExerciseListView()
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(AppTab.profile)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(AppTab.history)

            WorkoutView()
                .tabItem {
                    Label("Create Workout", systemImage: "plus")
                }
                .tag(AppTab.createWorkout)

            ExerciseListView()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell")
                }
                .tag(AppTab.exercises)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }

    // MARK: - iCloud Sync announcement

    /// One-time card telling existing users iCloud Sync arrived. Held back until onboarding is
    /// done so a brand-new user's first frame isn't two overlays deep.
    private var showsCloudSyncAnnouncement: Bool {
        hasCompletedOnboarding && !cloudSyncPreference.hasSeenAnnouncement && !cloudSyncPreference.isEnabled
    }

    private var cloudSyncAnnouncementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appAccent)

                Text("New: iCloud Sync & Backup")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appTextPrimary)

                Spacer()

                Button {
                    cloudSyncPreference.hasSeenAnnouncement = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appTextSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text(revenueCatService.canAccess(.icloudSync)
                ? "Included with your Pro subscription. Turn it on in Settings to back up your workouts and sync them across your devices."
                : "Back up your workouts and sync them across your devices — now part of ForgeLyte Lift Pro.")
                .font(.system(size: 13))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                cloudSyncPreference.hasSeenAnnouncement = true
                selectedTab = .settings
            } label: {
                Text("Open Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.appBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 60)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

}

#Preview {
    ContentView()
        .environmentObject(RevenueCatService.shared)
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
