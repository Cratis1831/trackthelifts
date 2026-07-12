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
    @State private var isProBenefitsPresented = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    private let notificationService = NotificationService.shared
    @State private var showNotificationDeniedAlert = false
    @State private var showRestoreErrorAlert = false
    @State private var showRestoreResultAlert = false
    @State private var restoreResultMessage = ""

    private let weightUnitPreference = WeightUnitPreference.shared
    @State private var selectedUnit: WeightUnit = WeightUnitPreference.shared.unit
    @State private var previousUnit: WeightUnit?
    @State private var pendingUnit: WeightUnit?
    @State private var showUnitChangeConfirmation = false

    private var themePreference = ThemePreference.shared
    private var restTimerDurationPreference = RestTimerDurationPreference.shared
    private var intensityPreference = IntensityPreference.shared

    // Shared card/typography constants so every section reads as one system.
    private let cardBorder = Color.appBorder
    private let secondaryText = Color.appTextSecondary

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

    private var timerSoundBinding: Binding<Bool> {
        Binding(
            get: { TimerSoundPreference.shared.isEnabled },
            set: { TimerSoundPreference.shared.isEnabled = $0 }
        )
    }

    private var restTimerDurationBinding: Binding<TimeInterval> {
        Binding(
            get: { restTimerDurationPreference.duration },
            set: { restTimerDurationPreference.duration = $0 }
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
                Color.appCanvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        subscriptionSection
                        appSettingsSection
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
        .fullScreenCover(isPresented: $isProBenefitsPresented) {
            ProBenefitsView()
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
        .alert("Restore Purchases", isPresented: $showRestoreResultAlert) {
            Button("OK") { }
        } message: {
            Text(restoreResultMessage)
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

    // MARK: - Subscription

    @ViewBuilder
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Subscription")

            if revenueCatService.currentTier == .premium {
                proMemberRow
            } else {
                freeTierCard
                restorePurchasesButton
            }
        }
    }

    // Subscribed: a compact row is all that's needed here — the full feature list and
    // subscription-management actions live in ProBenefitsView, a tap away.
    private var proMemberRow: some View {
        Button {
            isProBenefitsPresented = true
        } label: {
            HStack(spacing: 12) {
                IconTile(color: .appAccent) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Track The Lifts Pro")
                        .font(.system(size: 16))
                        .foregroundColor(.appTextPrimary)
                    Text("Tap to view your benefits")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(secondaryText)
            }
        }
        .buttonStyle(.plain)
        .settingsCard()
    }

    private var freeTierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Plan")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(secondaryText)

                Text(revenueCatService.currentTier.displayName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(revenueCatService.currentTier.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.appAccent)
                            .font(.system(size: 12, weight: .bold))

                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundColor(secondaryText)
                    }
                }
            }

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
                .foregroundStyle(Color.onAppAction)
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .padding(.top, 8)
        }
        .settingsCard()
    }

    private var restorePurchasesButton: some View {
        Button {
            Task {
                let success = await revenueCatService.restorePurchases()
                if success {
                    restoreResultMessage = revenueCatService.currentTier == .premium
                        ? "Your premium subscription has been restored."
                        : "No active purchases were found to restore."
                    showRestoreResultAlert = true
                } else {
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
        .buttonStyle(AppSecondaryButtonStyle())
        .disabled(revenueCatService.isLoading)
    }

    // MARK: - App Settings

    // Every general preference lives in one card, one row per setting, so the page isn't a long
    // scroll of one-row sections each paying for its own header and border.
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("App Settings")

            VStack(alignment: .leading, spacing: 16) {
                remindersRow
                rowDivider
                restTimerDurationRow
                rowDivider
                timerSoundRow
                rowDivider
                intensityRow
                rowDivider
                accentColorRow
                rowDivider
                weightUnitRow
                rowDivider
                exportRow
                rowDivider
                resetOnboardingRow
            }
            .settingsCard()
        }
    }

    private var remindersRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: remindersToggleBinding) {
                HStack(spacing: 12) {
                    IconTile(color: Color(red: 0.90, green: 0.30, blue: 0.24)) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                    }
                    Text("Daily Workout Reminder")
                        .font(.system(size: 16))
                        .foregroundColor(.appTextPrimary)
                }
            }
            .tint(.appToggleTint)

            if notificationService.remindersEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .tint(.appAccent)
                .foregroundColor(.appTextPrimary)
            }
        }
    }

    private var restTimerDurationRow: some View {
        HStack(spacing: 12) {
            IconTile(color: Color(red: 0.95, green: 0.55, blue: 0.19)) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
            }
            Text("Rest Timer Duration")
                .font(.system(size: 16))
                .foregroundColor(.appTextPrimary)
            Spacer()

            Picker("Rest Timer Duration", selection: restTimerDurationBinding) {
                ForEach(RestTimerDurationPreference.options, id: \.self) { option in
                    Text(RestTimerDurationPreference.label(for: option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.appAccent)
        }
    }

    private var timerSoundRow: some View {
        Toggle(isOn: timerSoundBinding) {
            HStack(spacing: 12) {
                IconTile(color: Color(red: 0.58, green: 0.36, blue: 0.90)) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                }
                Text("Set Timer Sound")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextPrimary)
            }
        }
        .tint(.appToggleTint)
    }

    private var intensityRow: some View {
        HStack(spacing: 12) {
            IconTile(color: Color(red: 0.88, green: 0.38, blue: 0.50)) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Set Effort")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextPrimary)
                Text("Optional effort rating for each set")
                    .font(.system(size: 10))
                    .foregroundColor(secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Picker("Set Effort", selection: Binding(
                get: { intensityPreference.mode },
                set: { intensityPreference.mode = $0 }
            )) {
                ForEach(IntensityPreferenceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.appAccent)
        }
    }

    private var accentColorRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                IconTile(color: themePreference.accentColor) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("Accent Color")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextPrimary)
                Spacer()
            }

            HStack(spacing: 0) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        Haptics.selection()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            themePreference.theme = theme
                        }
                    } label: {
                        accentSwatch(for: theme)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func accentSwatch(for theme: AppTheme) -> some View {
        ZStack {
            Circle()
                .fill(theme.color)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
            if themePreference.theme == theme {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 38, height: 38)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    private var weightUnitRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconTile(color: Color(red: 0.20, green: 0.48, blue: 0.96)) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                }
                Text("Weight Unit")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextPrimary)
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
    }

    private var exportRow: some View {
        ShareLink(
            item: WorkoutCSVDocument(text: WorkoutExportService.buildCSV(in: modelContext)),
            preview: SharePreview("Workout History.csv")
        ) {
            HStack(spacing: 12) {
                IconTile(color: Color(red: 0.30, green: 0.72, blue: 0.40)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                }
                Text("Export Workout History (CSV)")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextPrimary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var resetOnboardingRow: some View {
        Button {
            hasCompletedOnboarding = false
        } label: {
            HStack(spacing: 12) {
                IconTile(color: Color(red: 0.40, green: 0.40, blue: 0.43)) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                }
                Text("Reset Onboarding")
                    .font(.system(size: 16))
                    .foregroundColor(.appTextPrimary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared building blocks

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.appUtility)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundColor(.appTextSecondary)
    }

    private var rowDivider: some View {
        Divider()
            .background(cardBorder)
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

private extension View {
    /// The dark rounded card chrome (fill + border + inset padding) shared by every Settings card.
    func settingsCard() -> some View {
        self
            .padding(16)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
    }
}

#Preview {
    SettingsView()
}
