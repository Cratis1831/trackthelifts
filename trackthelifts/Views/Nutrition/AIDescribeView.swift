//
//  AIDescribeView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

struct AIDescribeView: View {
    let selectedDay: Date
    let mealType: MealType

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var descriptionText = AIDescribeDraft.load()
    @State private var items: [ConfirmableDescribedFood] = []
    @State private var isDescribing = false
    @State private var errorMessage: String?
    @State private var editingItem: ConfirmableDescribedFood?

    private var trimmedDescription: String {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var includedItems: [ConfirmableDescribedFood] {
        items.filter(\.included)
    }

    private var canDescribe: Bool {
        trimmedDescription.count >= 3 && !isDescribing
    }

    private var canAddToMeal: Bool {
        !includedItems.isEmpty
            && includedItems.allSatisfy(\.hasUsableNutrition)
            && includedItems.allSatisfy {
                !$0.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        descriptionField
                        if let errorMessage {
                            statusCard(message: errorMessage)
                        }
                        if items.isEmpty {
                            guidance
                        } else {
                            confirmationList
                        }
                    }
                    .padding(20)
                }

                if isDescribing {
                    describingOverlay
                }
            }
            .navigationTitle("Describe with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
            .onChange(of: descriptionText) { _, newValue in
                AIDescribeDraft.save(newValue)
            }
            .safeAreaInset(edge: .bottom) {
                if !items.isEmpty {
                    addButton
                }
            }
            .sheet(item: $editingItem) { item in
                AIDescribeEditView(draft: item.draft) { updated in
                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                        items[index].applyEditedDraft(updated)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What did you eat?")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            TextField("2 eggs, toast with butter, half an avocado", text: $descriptionText, axis: .vertical)
                .font(.appBody)
                .lineLimit(6...12)
                .foregroundColor(.appTextPrimary)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .describeInputSurface()
            Text("Your description is sent to ForgeLyte to estimate foods. Confirm portions before logging.")
                .font(.appCaption)
                .foregroundColor(.appTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Clear") {
                    clearDraft()
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .disabled(trimmedDescription.isEmpty)
                Button(items.isEmpty ? "Describe" : "Describe Again") {
                    Task { await describe() }
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(!canDescribe)
            }
        }
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI estimated portions. Please confirm.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.appTextPrimary)
            Text("Name the foods and rough amounts. Nutrition is estimated, not manufacturer-verified.")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var confirmationList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confirm foods")
                .font(.appUtility)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(.appTextSecondary)
            Text("AI estimated portions. Please confirm.")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)

            ForEach($items) { $item in
                describedFoodCard($item)
            }
        }
    }

    private func describedFoodCard(_ item: Binding<ConfirmableDescribedFood>) -> some View {
        let food = item.wrappedValue
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Toggle("Include \(food.draft.name)", isOn: item.included)
                    .labelsHidden()
                    .tint(.appAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.draft.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.appTextPrimary)
                    Text(MealDescribe.portionLabel(food.parsed))
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                    HStack(spacing: 6) {
                        Text(
                            NutritionRounding.macrosCaption(
                                calories: food.draft.calories,
                                protein: food.draft.proteinGrams,
                                carbs: food.draft.carbsGrams,
                                fat: food.draft.fatGrams,
                                fiber: food.draft.fiberGrams
                            )
                        )
                    }
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                    Text("AI estimate · \(food.confidenceLabel)")
                        .font(.appCaption)
                        .foregroundColor(.appTextTertiary)
                    if !food.hasUsableNutrition, food.included {
                        Text("Edit this food to add calories, or pick a catalogue match.")
                            .font(.appCaption)
                            .foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            if !food.matches.isEmpty {
                Menu {
                    Button("Description only") {
                        item.wrappedValue.selectMatch(id: nil)
                    }
                    ForEach(food.matches) { match in
                        Button(matchLabel(match)) {
                            item.wrappedValue.selectMatch(id: match.id)
                        }
                    }
                } label: {
                    HStack {
                        Text(food.selectedMatch.map(matchLabel) ?? "Description only")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appTextPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appTextTertiary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(Color.appElevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                            .strokeBorder(Color.appBorder, lineWidth: 1)
                    }
                }
            }

            Button("Edit") {
                editingItem = food
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
        .opacity(food.included ? 1 : 0.45)
        .appCard()
    }

    private var addButton: some View {
        VStack(spacing: 8) {
            Button(addTitle) {
                saveIncluded()
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(!canAddToMeal)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.appCanvas)
    }

    private var addTitle: String {
        let count = includedItems.count
        if count <= 1 { return "Add to Meal" }
        return "Add \(count) Foods"
    }

    private var describingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Reading your description…")
                    .font(.appCaption)
                    .foregroundColor(.appTextPrimary)
            }
            .padding(20)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
        }
    }

    private func statusCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Couldn't describe that")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appTextPrimary)
            Text(message)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func matchLabel(_ food: RemoteFood) -> String {
        let calories = food.nutrition.calories.map { "\(NutritionRounding.caloriesText($0)) kcal" } ?? "Nutrition varies"
        let name = FoodNameFormatting.displayName(food.name)
        if let brand = FoodNameFormatting.optionalDisplayName(food.brand) {
            return "\(name) · \(brand) · \(calories)"
        }
        return "\(name) · \(calories)"
    }

    private func clearDraft() {
        descriptionText = ""
        AIDescribeDraft.clear()
        errorMessage = nil
    }

    private func describe() async {
        guard canDescribe else { return }
        isDescribing = true
        errorMessage = nil
        defer { isDescribing = false }

        do {
            let response = try await ForgeLyteSession.shared.describeMeal(trimmedDescription)
            let parsed = MealDescribe.confirmableItems(from: response)
            if parsed.isEmpty {
                items = []
                errorMessage = "Try a simpler description, like “2 eggs and toast”."
            } else {
                items = parsed
                descriptionText = ""
                AIDescribeDraft.clear()
            }
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }

    private func saveIncluded() {
        guard canAddToMeal else { return }
        let loggedAt: Date = {
            if Calendar.current.isDate(selectedDay, inSameDayAs: .now) {
                return .now
            }
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDay) ?? selectedDay
        }()

        for food in includedItems {
            let draft = food.draft
            let log = FoodLog(
                loggedAt: loggedAt,
                mealType: mealType,
                sourceType: .aiEstimate,
                sourceFoodID: draft.sourceFoodID,
                displayName: FoodNameFormatting.displayName(draft.name),
                brand: FoodNameFormatting.optionalDisplayName(draft.brand),
                quantity: draft.quantity,
                unit: draft.servingDescription ?? food.parsed.unit,
                weightGrams: draft.servingWeightGrams,
                calories: draft.calories,
                proteinGrams: draft.proteinGrams,
                carbsGrams: draft.carbsGrams,
                fatGrams: draft.fatGrams,
                fiberGrams: draft.fiberGrams,
                sugarGrams: draft.sugarGrams,
                sodiumMilligrams: draft.sodiumMilligrams,
                isEstimated: true
            )
            modelContext.insert(log)
        }

        try? modelContext.save()
        NutritionBackupService.shared.markDirty()
        dismiss()
    }
}

private struct AIDescribeEditView: View {
    @State private var name: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String
    @Environment(\.dismiss) private var dismiss

    private let original: FoodEntryDraft
    var onSave: (FoodEntryDraft) -> Void

    init(draft: FoodEntryDraft, onSave: @escaping (FoodEntryDraft) -> Void) {
        original = draft
        self.onSave = onSave
        _name = State(initialValue: draft.name)
        _calories = State(initialValue: NutritionRounding.caloriesText(draft.calories))
        _protein = State(initialValue: NutritionRounding.macroText(draft.proteinGrams))
        _carbs = State(initialValue: NutritionRounding.macroText(draft.carbsGrams))
        _fat = State(initialValue: NutritionRounding.macroText(draft.fatGrams))
        _fiber = State(initialValue: draft.fiberGrams.map { NutritionRounding.macroText($0) } ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Double(calories) ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        labeledField("Food", text: $name, placeholder: "Chicken breast")
                        labeledField("Calories", text: $calories, placeholder: "0", keyboard: .decimalPad)
                        HStack(spacing: 10) {
                            labeledField("Protein (g)", text: $protein, placeholder: "0", keyboard: .decimalPad)
                            labeledField("Carbs (g)", text: $carbs, placeholder: "0", keyboard: .decimalPad)
                            labeledField("Fat (g)", text: $fat, placeholder: "0", keyboard: .decimalPad)
                        }
                        labeledField("Fiber (g)", text: $fiber, placeholder: "0", keyboard: .decimalPad)
                        Text("AI estimate — confirm portions before logging.")
                            .font(.appCaption)
                            .foregroundColor(.appTextTertiary)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appAccent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .decimalPad ? .never : .words)
                .foregroundColor(.appTextPrimary)
                .appInputSurface()
        }
    }

    private func save() {
        var draft = original
        draft.name = FoodNameFormatting.displayName(name)
        draft.calories = NutritionRounding.calories(Double(calories) ?? 0)
        draft.proteinGrams = NutritionRounding.macro(Double(protein) ?? 0)
        draft.carbsGrams = NutritionRounding.macro(Double(carbs) ?? 0)
        draft.fatGrams = NutritionRounding.macro(Double(fat) ?? 0)
        draft.fiberGrams = fiber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : NutritionRounding.macro(Double(fiber) ?? 0)
        draft.sourceType = .aiEstimate
        draft.isEstimated = true
        onSave(draft)
        dismiss()
    }
}

private extension View {
    func describeInputSurface() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 148, alignment: .topLeading)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
    }
}
