//
//  AddFoodView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

struct AddFoodView: View {
    let selectedDay: Date
    let customFoods: [CustomFood]
    var initialMeal: MealType? = nil

    @EnvironmentObject private var revenueCatService: RevenueCatService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedMeal.lastUsedAt, order: .reverse) private var savedMeals: [SavedMeal]
    @State private var query = ""
    @State private var selectedMeal: MealType
    @State private var isManualPresented = false
    @State private var selectedProFeature: ProFeature?
    @State private var comingSoonFeature: ProFeature?
    @State private var isScannerPresented = false
    @State private var isDescribePresented = false
    @State private var isLabelScannerPresented = false
    @State private var labelBarcode: String?
    @State private var remoteFoods: [RemoteFood] = []
    @State private var isSearchingRemote = false
    @State private var catalogueError: String?
    @State private var selectedDraft: FoodEntryDraft?

    init(selectedDay: Date, customFoods: [CustomFood], initialMeal: MealType? = nil) {
        self.selectedDay = selectedDay
        self.customFoods = customFoods
        self.initialMeal = initialMeal
        _selectedMeal = State(initialValue: initialMeal ?? Self.defaultMeal(for: .now))
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedQuery.isEmpty
    }

    private var filteredFoods: [CustomFood] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(customFoods.prefix(8))
        }
        return customFoods.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
            || ($0.brand?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var visibleSavedMeals: [SavedMeal] {
        let trimmed = trimmedQuery
        if trimmed.isEmpty { return savedMeals }
        return savedMeals.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var canSearchCatalogue: Bool {
        revenueCatService.canAccess(.foodSearch)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        mealPicker
                        searchField
                        if !isSearching {
                            entryMethods
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                                ))
                        }
                        if !visibleSavedMeals.isEmpty {
                            savedMealSection
                        }
                        if !filteredFoods.isEmpty {
                            foodSection(title: query.isEmpty ? "Recent" : "Yours", foods: filteredFoods)
                        }
                        remoteResults
                    }
                    .padding(20)
                    .animation(.easeInOut(duration: 0.28), value: isSearching)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appAccent)
                }
                ToolbarItem(placement: .primaryAction) {
                    if isSearching {
                        Menu {
                            Button("Add Manually", systemImage: "square.and.pencil") {
                                isManualPresented = true
                            }
                            Button("Scan Barcode", systemImage: "barcode.viewfinder") {
                                handleAdvanced(.barcodeScan)
                            }
                            Button("Scan Nutrition Facts", systemImage: "doc.text.viewfinder") {
                                handleAdvanced(.labelScan)
                            }
                            Button("Describe with AI", systemImage: "text.bubble.fill") {
                                handleAdvanced(.aiDescribe)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.appAccent)
                        }
                        .accessibilityLabel("More ways to add food")
                    }
                }
            }
            .sheet(isPresented: $isManualPresented) {
                ManualFoodEntryView(selectedDay: selectedDay, mealType: selectedMeal)
            }
            .sheet(item: $selectedDraft) { draft in
                ManualFoodEntryView(
                    selectedDay: selectedDay,
                    mealType: selectedMeal,
                    draft: draft
                )
            }
            .sheet(item: $comingSoonFeature) { feature in
                NutritionComingSoonView(feature: feature)
            }
            .sheet(isPresented: $isScannerPresented) {
                BarcodeScanView(
                    customFoods: customFoods,
                    onScanNutritionFacts: { code in
                        isScannerPresented = false
                        labelBarcode = code
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            isLabelScannerPresented = true
                        }
                    }
                ) { draft in
                    isScannerPresented = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        selectedDraft = draft
                    }
                }
            }
            .sheet(isPresented: $isLabelScannerPresented, onDismiss: {
                labelBarcode = nil
            }) {
                LabelScanView(barcode: labelBarcode) { draft in
                    isLabelScannerPresented = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        selectedDraft = draft
                    }
                }
            }
            .sheet(isPresented: $isDescribePresented) {
                AIDescribeView(selectedDay: selectedDay, mealType: selectedMeal)
            }
            .proPaywall(feature: $selectedProFeature)
            .task(id: query) {
                await searchRemoteIfNeeded()
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meal")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            Picker("Meal", selection: $selectedMeal) {
                ForEach(MealType.allCases) { meal in
                    Text(meal.displayName).tag(meal)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.appTextSecondary)
            TextField("Search foods...", text: $query)
                .foregroundColor(.appTextPrimary)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
        }
        .appInputSurface()
    }

    private var entryMethods: some View {
        VStack(alignment: .leading, spacing: 10) {
            methodButton(title: "Add Manually", systemImage: "square.and.pencil", feature: nil) {
                isManualPresented = true
            }
            methodButton(title: "Scan Barcode", systemImage: "barcode.viewfinder", feature: .barcodeScan) {
                handleAdvanced(.barcodeScan)
            }
            methodButton(title: "Scan Nutrition Facts", systemImage: "doc.text.viewfinder", feature: .labelScan) {
                handleAdvanced(.labelScan)
            }
            methodButton(title: "Describe with AI", systemImage: "text.bubble.fill", feature: .aiDescribe) {
                handleAdvanced(.aiDescribe)
            }
        }
    }

    @ViewBuilder
    private var remoteResults: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2 {
            if !canSearchCatalogue {
                Button {
                    selectedProFeature = .foodSearch
                } label: {
                    HStack(spacing: 12) {
                        IconTile(color: .appAccent) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Search the food catalogue")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.appTextPrimary)
                            Text("Unlock USDA and Open Food Facts with Pro")
                                .font(.appCaption)
                                .foregroundColor(.appTextSecondary)
                        }
                        Spacer()
                        ProBadge()
                    }
                    .appCard()
                }
                .buttonStyle(.plain)
            } else if isSearchingRemote {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching catalogue…")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
            } else if !remoteFoods.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Catalogue")
                        .font(.appUtility)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundColor(.appTextSecondary)

                    ForEach(remoteFoods) { food in
                        Button {
                            selectedDraft = food.draft
                        } label: {
                            foodRow(
                                name: food.listTitle,
                                brand: food.listBrand,
                                detail: "\(food.energyLabel) · \(food.servingLabel)",
                                macros: food.macrosLabel,
                                attribution: food.sourceType.displayName
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if let catalogueError {
                catalogueStatusCard(
                    title: "Catalogue unavailable",
                    message: catalogueError
                )
            } else {
                catalogueStatusCard(
                    title: "No catalogue matches",
                    message: "USDA and Open Food Facts didn’t return foods for this search. Try again, or add it manually."
                )
            }
        }
    }

    private func foodSection(title: String, foods: [CustomFood]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.appUtility)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(.appTextSecondary)

            ForEach(foods, id: \.id) { food in
                Button {
                    selectedDraft = food.draft
                } label: {
                    foodRow(
                        name: FoodNameFormatting.displayName(food.name),
                        brand: FoodNameFormatting.optionalDisplayName(food.brand),
                        detail: "\(NutritionRounding.caloriesText(food.calories)) kcal · \(food.servingDescription ?? "1 serving")",
                        macros: [
                            "P \(NutritionRounding.macroText(food.proteinGrams))",
                            "C \(NutritionRounding.macroText(food.carbsGrams))",
                            "F \(NutritionRounding.macroText(food.fatGrams))",
                            food.fiberGrams.map { "Fi \(NutritionRounding.macroText($0))" }
                        ]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func foodRow(
        name: String,
        brand: String? = nil,
        detail: String,
        macros: String? = nil,
        attribution: String? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                if let brand, !brand.isEmpty {
                    Text(brand)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                Text(detail)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                if let macros, !macros.isEmpty {
                    Text(macros)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                if let attribution {
                    Text(attribution)
                        .font(.appCaption)
                        .foregroundColor(.appTextTertiary)
                }
            }
            Spacer()
        }
        .appCard(padding: 12)
    }

    private func methodButton(
        title: String,
        systemImage: String,
        feature: ProFeature?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(color: .appAccent) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                if let feature, revenueCatService.requiresPro(feature) {
                    ProBadge()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appTextTertiary)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }

    private func catalogueStatusCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appTextPrimary)
            Text(message)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try Again") {
                Task { await searchRemoteIfNeeded(immediate: true) }
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
        .appCard()
    }

    private func handleAdvanced(_ feature: ProFeature) {
        if revenueCatService.canAccess(feature) {
            switch feature {
            case .barcodeScan:
                isScannerPresented = true
            case .labelScan:
                labelBarcode = nil
                isLabelScannerPresented = true
            case .aiDescribe:
                isDescribePresented = true
            default:
                comingSoonFeature = feature
            }
        } else {
            selectedProFeature = feature
        }
    }

    private func searchRemoteIfNeeded(immediate: Bool = false) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, canSearchCatalogue else {
            remoteFoods = []
            catalogueError = nil
            isSearchingRemote = false
            return
        }

        if !immediate {
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
        }

        isSearchingRemote = true
        catalogueError = nil
        defer { isSearchingRemote = false }
        do {
            remoteFoods = try await ForgeLyteSession.shared.searchFoods(trimmed)
            catalogueError = nil
        } catch {
            remoteFoods = []
            catalogueError = error.localizedDescription
        }
    }

    private var savedMealSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved meals")
                .font(.appUtility)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(.appTextSecondary)

            ForEach(visibleSavedMeals, id: \.id) { meal in
                Button {
                    addSavedMeal(meal)
                } label: {
                    foodRow(
                        name: meal.name,
                        detail: "\(meal.foods.count) food\(meal.foods.count == 1 ? "" : "s") · \(NutritionRounding.caloriesText(meal.foods.reduce(0) { $0 + $1.calories })) kcal"
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        modelContext.delete(meal)
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    private func addSavedMeal(_ meal: SavedMeal) {
        let foods = meal.foods
        guard !foods.isEmpty else { return }
        let existingCount = (try? modelContext.fetch(FetchDescriptor<FoodLog>()))?.count ?? 0
        if !NutritionAccessPolicy.canLogManually(
            existingLogCount: existingCount + foods.count - 1,
            tier: revenueCatService.currentTier
        ) {
            selectedProFeature = .calorieTracking
            return
        }
        let loggedAt: Date = {
            if Calendar.current.isDate(selectedDay, inSameDayAs: .now) {
                return .now
            }
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDay) ?? selectedDay
        }()
        for food in foods {
            modelContext.insert(
                FoodLog(
                    loggedAt: loggedAt,
                    mealType: selectedMeal,
                    sourceType: FoodSourceType(rawValue: food.sourceTypeRaw) ?? .custom,
                    sourceFoodID: food.sourceFoodID,
                    displayName: food.displayName,
                    brand: food.brand,
                    quantity: food.quantity,
                    unit: food.unit,
                    weightGrams: food.weightGrams,
                    calories: food.calories,
                    proteinGrams: food.proteinGrams,
                    carbsGrams: food.carbsGrams,
                    fatGrams: food.fatGrams,
                    fiberGrams: food.fiberGrams,
                    sugarGrams: food.sugarGrams,
                    sodiumMilligrams: food.sodiumMilligrams,
                    isEstimated: food.isEstimated
                )
            )
        }
        meal.lastUsedAt = .now
        try? modelContext.save()
        dismiss()
    }

    private static func defaultMeal(for date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<21: return .dinner
        default: return .snack
        }
    }
}
