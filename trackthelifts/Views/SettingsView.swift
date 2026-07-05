//
//  SettingsView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var revenueCatService: RevenueCatService
    @State private var isPaywallPresented = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    private let notificationService = NotificationService.shared
    @State private var showNotificationDeniedAlert = false
    @State private var showRestoreErrorAlert = false

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
                                    await revenueCatService.restorePurchases()
                                    if revenueCatService.lastError != nil {
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
                                    Text("Daily Workout Reminder")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
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
                                    HStack {
                                        Text("Reset Onboarding")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)

                                        Spacer()

                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.orange)
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
    }
}

#Preview {
    SettingsView()
}
