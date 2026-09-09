//
//  NutritionView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.nutritionContainer) private var nutritionContainer

    var body: some View {
        if let nutritionContainer {
            NutritionDashboardView()
                .modelContainer(nutritionContainer)
        }
    }
}

struct NutritionDashboardView: View {
    @EnvironmentObject private var revenueCatService: RevenueCatService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodLog.loggedAt, order: .reverse) private var allLogs: [FoodLog]
    @Query(sort: \CustomFood.lastUsedAt, order: .reverse) private var customFoods: [CustomFood]

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var isAddFoodPresented = false
    @State private var isTargetsPresented = false
    @State private var selectedProFeature: ProFeature?
    @State private var targets = NutritionPreference.shared
    @State private var logToEdit: FoodLog?

    private var dayLogs: [FoodLog] {
        NutritionMath.logs(on: selectedDay, from: allLogs)
    }

    private var totals: NutritionMath.Totals {
        NutritionMath.totals(from: dayLogs)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDay)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()
                PrecisionGridBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        daySwitcher
                        calorieCard
                        macroRow
                        if let remaining = NutritionAccessPolicy.remainingFreeLogs(
                            existingLogCount: allLogs.count,
                            tier: revenueCatService.currentTier
                        ), remaining <= NutritionAccessPolicy.freeManualLogLimit {
                            freePreviewBanner(remaining: remaining)
                        }
                        mealsSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentAddFood()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add food")
                }
            }
            .sheet(isPresented: $isAddFoodPresented) {
                AddFoodView(
                    selectedDay: selectedDay,
                    customFoods: customFoods
                )
            }
            .sheet(item: $logToEdit) { log in
                ManualFoodEntryView(existingLog: log, selectedDay: selectedDay)
            }
            .sheet(isPresented: $isTargetsPresented) {
                NutritionTargetsView()
            }
            .proPaywall(feature: $selectedProFeature)
        }
    }

    private var daySwitcher: some View {
        HStack {
            Button {
                selectedDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                            .strokeBorder(Color.appBorder, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(isToday ? "Today" : selectedDay.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                if !isToday {
                    Button("Jump to Today") {
                        selectedDay = Calendar.current.startOfDay(for: .now)
                    }
                    .font(.appCaption)
                    .foregroundColor(.appAccent)
                }
            }

            Spacer()

            Button {
                let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
                if next <= Calendar.current.startOfDay(for: .now) {
                    selectedDay = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isToday ? .appTextTertiary : .appTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                            .strokeBorder(Color.appBorder, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isToday)
        }
    }

    private var calorieCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calories")
                    .font(.appSectionTitle)
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Button {
                    isTargetsPresented = true
                } label: {
                    Text(targets.hasSetTargets ? "Edit Targets" : "Set Targets")
                        .font(.appCaption)
                        .foregroundColor(.appAccent)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(totals.calories.rounded()))")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                if targets.hasSetTargets {
                    Text("/ \(Int(targets.calories.rounded())) kcal")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                } else {
                    Text("kcal")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
            }

            NutritionProgressBar(
                progress: targets.hasSetTargets ? totals.calories / max(targets.calories, 1) : 0
            )
        }
        .appCard()
    }

    private var macroRow: some View {
        HStack(spacing: 10) {
            macroCard(title: "Protein", value: totals.proteinGrams, target: targets.proteinGrams, unit: "g")
            macroCard(title: "Carbs", value: totals.carbsGrams, target: targets.carbsGrams, unit: "g")
            macroCard(title: "Fat", value: totals.fatGrams, target: targets.fatGrams, unit: "g")
        }
    }

    private func macroCard(title: String, value: Double, target: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            Text("\(Int(value.rounded()))\(unit)")
                .font(.appMetric)
                .foregroundColor(.appTextPrimary)
            if targets.hasSetTargets, target > 0 {
                NutritionProgressBar(progress: value / target)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 12)
    }

    private func freePreviewBanner(remaining: Int) -> some View {
        Button {
            selectedProFeature = .calorieTracking
        } label: {
            HStack(alignment: .top, spacing: 12) {
                IconTile(color: .appAccent) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(remaining == 0 ? "Preview used" : "\(remaining) free log\(remaining == 1 ? "" : "s") left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        ProBadge()
                    }
                    Text("Pro unlocks unlimited logging, food search, barcode scanning, and AI.")
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(MealType.allCases) { meal in
                mealCard(meal)
            }
        }
    }

    private func mealCard(_ meal: MealType) -> some View {
        let items = dayLogs.filter { $0.mealType == meal }
        let mealTotals = NutritionMath.totals(from: items)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 10) {
                    IconTile(color: .appAccent) {
                        Image(systemName: meal.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(meal.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        if !items.isEmpty {
                            Text("\(Int(mealTotals.calories.rounded())) kcal")
                                .font(.appCaption)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }
                Spacer()
                Button {
                    presentAddFood()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appAccent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add to \(meal.displayName)")
            }

            if items.isEmpty {
                Text("No foods logged")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextTertiary)
            } else {
                VStack(spacing: 8) {
                    ForEach(items, id: \.id) { log in
                        Button {
                            logToEdit = log
                        } label: {
                            foodRow(log)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit") { logToEdit = log }
                            Button("Delete", role: .destructive) { delete(log) }
                        }
                    }
                }
            }
        }
        .appCard()
    }

    private func foodRow(_ log: FoodLog) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(log.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                HStack(spacing: 6) {
                    Text("\(Int(log.calories.rounded())) kcal")
                    Text("·")
                    Text("P \(Int(log.proteinGrams.rounded()))")
                    Text("C \(Int(log.carbsGrams.rounded()))")
                    Text("F \(Int(log.fatGrams.rounded()))")
                    if log.isEstimated {
                        Text("Est.")
                    }
                }
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appTextTertiary)
        }
    }

    private func presentAddFood() {
        if NutritionAccessPolicy.canLogManually(
            existingLogCount: allLogs.count,
            tier: revenueCatService.currentTier
        ) {
            isAddFoodPresented = true
        } else {
            selectedProFeature = .calorieTracking
        }
    }

    private func delete(_ log: FoodLog) {
        modelContext.delete(log)
        try? modelContext.save()
    }
}

private struct NutritionProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.appBorder)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.appAccent)
                    .frame(width: max(proxy.size.width * clamped, progress > 0 ? 4 : 0))
            }
        }
        .frame(height: 6)
    }
}

#Preview {
    NutritionDashboardView()
        .environmentObject(RevenueCatService.shared)
        .modelContainer(for: [FoodLog.self, CustomFood.self], inMemory: true)
}
