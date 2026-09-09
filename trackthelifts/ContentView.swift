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
        case profile, history, createWorkout, exercises, nutrition
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var revenueCatService: RevenueCatService
    @State private var selectedTab: AppTab = .profile
    private var cloudSyncPreference = CloudSyncPreference.shared
    private var whatsNewPreference = WhatsNewPreference.shared
    private var productChangeAnnouncement = ProductChangeAnnouncementPreference.shared

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
        .sheet(isPresented: productAnnouncementBinding) {
            ProductChangeAnnouncementView(
                onContinue: dismissProductAnnouncement,
                onOpenNutrition: {
                    dismissProductAnnouncement()
                    selectedTab = .nutrition
                }
            )
        }
        .sheet(isPresented: whatsNewSheetBinding) {
            if let release = ReleaseCatalog.current {
                WhatsNewUpdateSheet(release: release) {
                    whatsNewPreference.markCurrentVersionSeen()
                }
            }
        }
        .watchesRestTimerCompletion()
        .onAppear {
            UIApplication.shared.enableTapToDismissKeyboard()
            ExerciseData.seedIfNeeded(in: modelContext)
            PrebuiltRoutineCatalog.seedIfNeeded(in: modelContext)
            WorkoutSessionManager.shared.reconcileOrphanedActiveWorkouts(in: modelContext)
            if CloudSyncPreference.shared.isStoreMirrored {
                CloudSyncMergeService.mergeDuplicates(in: modelContext)
            }
            Task { await NutritionBackupService.shared.syncOnForeground() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Task { await NutritionBackupService.shared.pushIfNeeded() }
            } else if phase == .active {
                Task { await NutritionBackupService.shared.syncOnForeground() }
            }
        }
        .onChange(of: revenueCatService.currentTier) { _, tier in
            if tier == .pro {
                Task { await NutritionBackupService.shared.syncOnForeground() }
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

            Tab("Nutrition", systemImage: "fork.knife", value: .nutrition) {
                NutritionView()
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

            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
                .tag(AppTab.nutrition)
        }
    }

    // MARK: - iCloud Sync announcement

    /// One-time card telling existing users iCloud Sync arrived. Held back until onboarding and
    /// the version announcement sheets have been dismissed so the first frame isn't two overlays deep.
    private var showsCloudSyncAnnouncement: Bool {
        hasCompletedOnboarding
            && !showsWhatsNew
            && !showsProductAnnouncement
            && !cloudSyncPreference.hasSeenAnnouncement
            && !cloudSyncPreference.isEnabled
    }

    private var showsProductAnnouncement: Bool {
        productChangeAnnouncement.shouldPresent(hasCompletedOnboarding: hasCompletedOnboarding)
    }

    private var showsWhatsNew: Bool {
        !showsProductAnnouncement
            && whatsNewPreference.shouldPresent(hasCompletedOnboarding: hasCompletedOnboarding)
    }

    private var productAnnouncementBinding: Binding<Bool> {
        Binding(
            get: { showsProductAnnouncement },
            set: { isPresented in
                if !isPresented {
                    dismissProductAnnouncement()
                }
            }
        )
    }

    private func dismissProductAnnouncement() {
        productChangeAnnouncement.markSeen()
        whatsNewPreference.markCurrentVersionSeen()
    }

    private var whatsNewSheetBinding: Binding<Bool> {
        Binding(
            get: { showsWhatsNew },
            set: { isPresented in
                if !isPresented {
                    whatsNewPreference.markCurrentVersionSeen()
                }
            }
        )
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

            Text("Back up your workouts and sync them across your devices. Turn it on in Settings — your food diary stays on this iPhone.")
                .font(.system(size: 13))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                cloudSyncPreference.hasSeenAnnouncement = true
                selectedTab = .profile
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
        .environment(\.nutritionContainer, NutritionStore.makeContainer())
        .modelContainer(for: [
            Workout.self, Exercise.self, Bodypart.self,
            ExerciseSet.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
        ])
}
