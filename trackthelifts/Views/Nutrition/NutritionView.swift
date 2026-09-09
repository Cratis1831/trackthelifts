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
    @State private var copyMeal: MealType?
    @State private var copyToTodayMeal: MealType?
    @State private var saveMeal: MealType?
    @State private var saveMealName = ""
    @State private var savedMealConfirmation: String?
    @State private var mealToClear: MealType?
    @State private var swipedFoodID: UUID?
    @State private var addFoodMeal: MealType?
    private let foodDeleteWidth: CGFloat = 52

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

                List {
                    Section {
                        daySwitcher
                            .listRowInsets(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        calorieCard
                            .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        macroRow
                            .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        if let remaining = NutritionAccessPolicy.remainingFreeLogs(
                            existingLogCount: allLogs.count,
                            tier: revenueCatService.currentTier
                        ), remaining <= NutritionAccessPolicy.freeManualLogLimit {
                            freePreviewBanner(remaining: remaining)
                                .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listSectionSeparator(.hidden)

                    ForEach(MealType.allCases) { meal in
                        mealFoodSection(meal)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .environment(\.defaultMinListRowHeight, 1)
                .padding(.horizontal, 20)
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
            .sheet(isPresented: $isAddFoodPresented, onDismiss: {
                addFoodMeal = nil
            }) {
                AddFoodView(
                    selectedDay: selectedDay,
                    customFoods: customFoods,
                    initialMeal: addFoodMeal
                )
            }
            .sheet(item: $logToEdit) { log in
                ManualFoodEntryView(existingLog: log, selectedDay: selectedDay)
            }
            .sheet(item: $copyMeal) { meal in
                CopyMealSheet(
                    title: "Copy Meal",
                    sources: MealCopying.sources(
                        from: allLogs,
                        relativeTo: selectedDay,
                        excluding: meal
                    ),
                    destinationMeal: meal
                ) { source, destination in
                    copy(source, to: destination, on: selectedDay)
                }
            }
            .sheet(item: $copyToTodayMeal) { meal in
                let items = dayLogs.filter { $0.mealType == meal }
                CopyToTodaySheet(
                    meal: meal,
                    itemCount: items.count,
                    calories: NutritionMath.totals(from: items).calories
                ) { destination in
                    copyItems(items, to: destination, on: Calendar.current.startOfDay(for: .now))
                }
            }
            .appConfirm(
                item: $mealToClear,
                title: { "Clear \($0.displayName)?" },
                message: { "This removes every food in \($0.displayName) for this day." },
                confirmTitle: "Delete all foods",
                onConfirm: { clearMeal($0) }
            )
            .appPrompt(
                "Save Meal",
                item: $saveMeal,
                message: "Saved on this iPhone. Add it later without searching.",
                text: $saveMealName,
                placeholder: "Name",
                onConfirm: { persistSavedMeal($0) }
            )
            .appNotice(
                "Meal saved",
                isPresented: Binding(
                    get: { savedMealConfirmation != nil },
                    set: { if !$0 { savedMealConfirmation = nil } }
                ),
                message: "“\(savedMealConfirmation ?? "")” is on this iPhone. Add it from Add Food."
            )
            .sheet(isPresented: $isTargetsPresented) {
                NutritionTargetsView()
            }
            .proPaywall(feature: $selectedProFeature)
            .onChange(of: selectedDay) { _, _ in
                swipedFoodID = nil
            }
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
                Text(NutritionRounding.caloriesText(totals.calories))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                if targets.hasSetTargets {
                    Text("/ \(NutritionRounding.caloriesText(targets.calories)) kcal")
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
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                macroCard(title: "Protein", value: totals.proteinGrams, target: targets.proteinGrams, unit: "g")
                macroCard(title: "Carbs", value: totals.carbsGrams, target: targets.carbsGrams, unit: "g")
            }
            HStack(spacing: 10) {
                macroCard(title: "Fat", value: totals.fatGrams, target: targets.fatGrams, unit: "g")
                macroCard(title: "Fiber", value: totals.fiberGrams, target: targets.fiberGrams, unit: "g")
            }
        }
    }

    private func macroCard(title: String, value: Double, target: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            Text("\(NutritionRounding.macroText(value))\(unit)")
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

    private func mealFoodSection(_ meal: MealType) -> some View {
        let items = dayLogs.filter { $0.mealType == meal }
        let mealTotals = NutritionMath.totals(from: items)

        return Section {
            VStack(alignment: .leading, spacing: items.isEmpty ? 0 : 12) {
                mealHeader(meal, items: items, mealTotals: mealTotals)

                if !items.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(items, id: \.id) { log in
                            compactSwipeFoodRow(log)
                        }
                    }
                }
            }
            .appCard()
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowSeparatorTint(.clear)
            .listRowBackground(Color.clear)
        }
        .listSectionSeparator(.hidden)
        .listSectionSeparatorTint(.clear)
        .listSectionSpacing(24)
    }

    private func mealHeader(_ meal: MealType, items: [FoodLog], mealTotals: NutritionMath.Totals) -> some View {
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
                    if items.isEmpty {
                        Text("No foods logged")
                            .font(.appCaption)
                            .foregroundColor(.appTextTertiary)
                    } else {
                        Text("\(NutritionRounding.caloriesText(mealTotals.calories)) kcal")
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
            Spacer()
            Menu {
                Button("Copy from recent", systemImage: "doc.on.doc") {
                    copyMeal = meal
                }
                if !items.isEmpty {
                    Button("Save meal", systemImage: "square.and.arrow.down") {
                        saveMealName = MealCopying.defaultSavedName(meal: meal, items: items)
                        saveMeal = meal
                    }
                    Button("Clear meal", systemImage: "trash", role: .destructive) {
                        mealToClear = meal
                    }
                }
                if !isToday && !items.isEmpty {
                    Button("Copy to today", systemImage: "arrow.uturn.forward") {
                        copyToTodayMeal = meal
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appAccent)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("\(meal.displayName) meal actions")
            Button {
                addFoodMeal = meal
                presentAddFood()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add to \(meal.displayName)")
        }
    }

    private func compactSwipeFoodRow(_ log: FoodLog) -> some View {
        let revealed = swipedFoodID == log.id
        return ZStack(alignment: .trailing) {
            Button {
                delete(log)
                swipedFoodID = nil
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: foodDeleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(log.displayName)")

            foodRow(log)
                .padding(.vertical, 2)
                .background(Color.appSurface)
                .offset(x: revealed ? -foodDeleteWidth - 8 : 0)
                .onTapGesture {
                    if revealed {
                        withAnimation(.easeOut(duration: 0.18)) { swipedFoodID = nil }
                    } else {
                        logToEdit = log
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24, coordinateSpace: .local)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            withAnimation(.easeOut(duration: 0.12)) {
                                if value.translation.width < -20 {
                                    swipedFoodID = log.id
                                } else if value.translation.width > 12 {
                                    swipedFoodID = nil
                                }
                            }
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.18)) {
                                if value.translation.width < -foodDeleteWidth / 2 {
                                    swipedFoodID = log.id
                                } else {
                                    swipedFoodID = nil
                                }
                            }
                        }
                )
        }
        .clipped()
        .animation(.easeOut(duration: 0.18), value: revealed)
        .contextMenu {
            Button("Edit") { logToEdit = log }
            Button("Delete", role: .destructive) { delete(log) }
        }
    }

    private func foodRow(_ log: FoodLog) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(FoodNameFormatting.displayName(log.displayName))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)
                Text(
                    NutritionRounding.macrosCaption(
                        calories: log.calories,
                        protein: log.proteinGrams,
                        carbs: log.carbsGrams,
                        fat: log.fatGrams,
                        fiber: log.fiberGrams,
                        estimated: log.isEstimated
                    )
                )
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appTextTertiary)
        }
    }

    private func copy(_ source: MealCopying.Source, to meal: MealType, on day: Date) {
        let items = MealCopying.items(matching: source, in: allLogs)
        copyItems(items, to: meal, on: day)
    }

    private func copyItems(_ items: [FoodLog], to meal: MealType, on day: Date) {
        guard !items.isEmpty else { return }
        if !NutritionAccessPolicy.canLogManually(
            existingLogCount: allLogs.count + items.count - 1,
            tier: revenueCatService.currentTier
        ) {
            selectedProFeature = .calorieTracking
            return
        }
        for log in MealCopying.copy(items, to: meal, on: day) {
            modelContext.insert(log)
        }
        try? modelContext.save()
        NutritionBackupService.shared.markDirty()
    }

    private func persistSavedMeal(_ meal: MealType) {
        let items = dayLogs.filter { $0.mealType == meal }
        guard !items.isEmpty else { return }
        let name = saveMealName.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = SavedMeal(
            name: name.isEmpty ? MealCopying.defaultSavedName(meal: meal, items: items) : name,
            foods: items.map(SavedMealFood.init(log:))
        )
        modelContext.insert(saved)
        try? modelContext.save()
        NutritionBackupService.shared.markDirty()
        saveMeal = nil
        saveMealName = ""
        savedMealConfirmation = saved.name
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
        NutritionBackupService.shared.markDirty()
    }

    private func clearMeal(_ meal: MealType) {
        for log in dayLogs.filter({ $0.mealType == meal }) {
            modelContext.delete(log)
        }
        try? modelContext.save()
        NutritionBackupService.shared.markDirty()
        mealToClear = nil
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
        .modelContainer(for: [FoodLog.self, CustomFood.self, SavedMeal.self], inMemory: true)
}
