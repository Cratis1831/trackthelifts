//
//  AddFoodView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

struct AddFoodView: View {
    let selectedDay: Date
    let customFoods: [CustomFood]

    @EnvironmentObject private var revenueCatService: RevenueCatService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedMeal: MealType = defaultMeal(for: .now)
    @State private var isManualPresented = false
    @State private var selectedProFeature: ProFeature?
    @State private var comingSoonFeature: ProFeature?
    @State private var isScannerPresented = false
    @State private var remoteFoods: [RemoteFood] = []
    @State private var isSearchingRemote = false
    @State private var selectedDraft: FoodEntryDraft?

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
                        entryMethods
                        if !filteredFoods.isEmpty {
                            foodSection(title: query.isEmpty ? "Recent" : "Yours", foods: filteredFoods)
                        }
                        remoteResults
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appAccent)
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
                BarcodeScanView(customFoods: customFoods) { draft in
                    isScannerPresented = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        selectedDraft = draft
                    }
                }
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
            methodButton(title: "Take Food Photo", systemImage: "camera.fill", feature: .foodPhoto) {
                handleAdvanced(.foodPhoto)
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
                                name: food.name,
                                detail: catalogueDetail(food),
                                attribution: food.sourceType.displayName
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
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
                        name: food.name,
                        detail: "\(Int(food.calories.rounded())) kcal · \(food.servingDescription ?? "1 serving")"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func foodRow(name: String, detail: String, attribution: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                Text(detail)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
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

    private func catalogueDetail(_ food: RemoteFood) -> String {
        let calories = food.nutrition.calories.map { "\(Int($0.rounded())) kcal" } ?? "Nutrition varies"
        let serving = food.serving.unit ?? food.serving.weightGrams.map { "\(Int($0)) g" } ?? "1 serving"
        return "\(calories) · \(serving)"
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

    private func handleAdvanced(_ feature: ProFeature) {
        if revenueCatService.canAccess(feature) {
            if feature == .barcodeScan {
                isScannerPresented = true
            } else {
                comingSoonFeature = feature
            }
        } else {
            selectedProFeature = feature
        }
    }

    private func searchRemoteIfNeeded() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, canSearchCatalogue else {
            remoteFoods = []
            isSearchingRemote = false
            return
        }

        try? await Task.sleep(for: .milliseconds(550))
        guard !Task.isCancelled else { return }

        isSearchingRemote = true
        defer { isSearchingRemote = false }
        do {
            remoteFoods = try await ForgeLyteSession.shared.searchFoods(trimmed)
        } catch {
            remoteFoods = []
        }
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
