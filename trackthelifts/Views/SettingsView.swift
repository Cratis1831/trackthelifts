//
//  SettingsView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var revenueCatService: RevenueCatService
    @Environment(\.modelContext) private var modelContext
    @State private var isPaywallPresented = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    private let notificationService = NotificationService.shared
    @State private var showNotificationDeniedAlert = false
    @State private var showRestoreErrorAlert = false

    private let weightUnitPreference = WeightUnitPreference.shared
    @State private var selectedUnit: WeightUnit = WeightUnitPreference.shared.unit
    @State private var previousUnit: WeightUnit?
    @State private var pendingUnit: WeightUnit?
    @State private var showUnitChangeConfirmation = false

    private var remindersToggleBinding: Binding<Bool> {
        Binding(
            get: { notificationService.remindersEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await notificationService.requestAuthorizationIfNeeded()
                        await MainActor.run {
                            if granted {
                                notificationService.remindersEnabled = true
                                notificationService.scheduleDailyReminder()
                            } else {
                                notificationService.remindersEnabled = false
                                showNotificationDeniedAlert = true
                            }
                        }
                    }
                } else {
                    notificationService.remindersEnabled = false
                    notificationService.cancelReminder()
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { notificationService.reminderTime },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationService.setReminderTime(hour: components.hour ?? 18, minute: components.minute ?? 0)
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Subscription Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Subscription")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                            
                            // Current Tier Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Current Plan")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                        
                                        Text(revenueCatService.currentTier.displayName)
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    if revenueCatService.currentTier == .premium {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 24))
                                    }
                                }
                                
                                // Features List
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(revenueCatService.currentTier.features, id: \.self) { feature in
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 12, weight: .bold))
                                            
                                            Text(feature)
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                        }
                                    }
                                }
                                
                                // Upgrade Button (only for free tier)
                                if revenueCatService.currentTier == .free {
                                    Button {
                                        isPaywallPresented = true
                                    } label: {
                                        HStack {
                                            Text("Upgrade to Premium")
                                                .font(.system(size: 16, weight: .semibold))
                                            
                                            Spacer()
                                            
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.roundedRectangle(radius: 12))
                                    .tint(.orange)
                                    .padding(.top, 8)
                                }
                            }
                            .padding(16)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
                            )
                            
                            // Restore Purchases Button
                            Button {
                                Task {
                                    let success = await revenueCatService.restorePurchases()
                                    if !success {
                                        showRestoreErrorAlert = true
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("Restore Purchases")
                                        .font(.system(size: 16))
                                    
                                    if revenueCatService.isLoading {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 12))
                            .tint(.orange)
                            .disabled(revenueCatService.isLoading)
                        }
                        
                        // App Settings Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("App Settings")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)

                            // Reminders Card
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: remindersToggleBinding) {
                                    HStack(spacing: 12) {
                                        IconTile(color: Color(red: 0.90, green: 0.30, blue: 0.24)) {
                                            Image(systemName: "bell.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                        Text("Daily Workout Reminder")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                    }
                                }
                                .tint(.orange)

                                if notificationService.remindersEnabled {
                                    DatePicker(
                                        "Reminder Time",
                                        selection: reminderTimeBinding,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .tint(.orange)
                                    .foregroundColor(.white)
                                }
                            }
                            .padding(16)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
                            )

                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    hasCompletedOnboarding = false
                                } label: {
                                    HStack(spacing: 12) {
                                        IconTile(color: Color(red: 0.40, green: 0.40, blue: 0.43)) {
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                        Text("Reset Onboarding")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)

                                        Spacer()
                                    }
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

                        // Units Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Units")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    IconTile(color: Color(red: 0.20, green: 0.48, blue: 0.96)) {
                                        Image(systemName: "scalemass.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    Text("Weight Unit")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                    Spacer()
                                }

                                Picker("Weight Unit", selection: $selectedUnit) {
                                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                                        Text(unit.label).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: selectedUnit) { oldValue, newValue in
                                    guard newValue != oldValue else { return }
                                    previousUnit = oldValue
                                    pendingUnit = newValue
                                    showUnitChangeConfirmation = true
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

                        // Data Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Data")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 12) {
                                ShareLink(
                                    item: WorkoutCSVDocument(text: WorkoutExportService.buildCSV(in: modelContext)),
                                    preview: SharePreview("Workout History.csv")
                                ) {
                                    HStack(spacing: 12) {
                                        IconTile(color: Color(red: 0.30, green: 0.72, blue: 0.40)) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                        Text("Export Workout History (CSV)")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)

                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Settings")
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView()
        }
        .alert("Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
            Button("OK") { }
        } message: {
            Text("Enable notifications for Track The Lifts in iOS Settings to turn on workout reminders.")
        }
        .alert("Restore Failed", isPresented: $showRestoreErrorAlert) {
            Button("OK") { }
        } message: {
            Text(revenueCatService.lastError?.localizedDescription ?? "Couldn't restore your purchases. Please try again.")
        }
        .alert("Change Weight Unit?", isPresented: $showUnitChangeConfirmation) {
            Button("Cancel", role: .cancel) {
                if let previousUnit {
                    selectedUnit = previousUnit
                }
            }
            Button("Convert") {
                if let previousUnit, let pendingUnit {
                    convertAllStoredWeights(from: previousUnit, to: pendingUnit)
                    weightUnitPreference.unit = pendingUnit
                }
            }
        } message: {
            Text("Switching to \(pendingUnit?.label ?? "") will convert all your logged weights. Continue?")
        }
    }

    private func convertAllStoredWeights(from oldUnit: WeightUnit, to newUnit: WeightUnit) {
        do {
            let sets = try modelContext.fetch(FetchDescriptor<ExerciseSet>())
            for set in sets where set.weight != 0 {
                set.weight = oldUnit.convertForStorage(set.weight, to: newUnit)
            }

            let templateExercises = try modelContext.fetch(FetchDescriptor<WorkoutTemplateExercise>())
            for templateExercise in templateExercises where templateExercise.targetWeight != 0 {
                templateExercise.targetWeight = oldUnit.convertForStorage(templateExercise.targetWeight, to: newUnit)
            }

            try modelContext.save()
        } catch {
            print("Failed to convert stored weights: \(error)")
        }
    }
}

#Preview {
    SettingsView()
}
