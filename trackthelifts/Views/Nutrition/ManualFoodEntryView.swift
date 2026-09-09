//
//  ManualFoodEntryView.swift
//  TrackTheLifts
//

import SwiftUI
import SwiftData

struct ManualFoodEntryView: View {
    var existingLog: FoodLog? = nil
    let selectedDay: Date
    var mealType: MealType = .lunch

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var selectedMeal: MealType
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var amountText = "1"
    @State private var selectedUnit: FoodServingUnit = .serving

    private let sourceType: FoodSourceType
    private let sourceFoodID: String?
    private let isEstimated: Bool
    private let draftServingDescription: String?
    private let gramsPerServing: Double?
    private let draftBarcode: String?
    private let draftSugar: Double?
    private let draftSodium: Double?
    private let baselineCalories: Double
    private let baselineProtein: Double
    private let baselineCarbs: Double
    private let baselineFat: Double
    private let baselineFiber: Double?
    private let referenceAmount: Double
    private let referenceUnit: FoodServingUnit

    init(
        existingLog: FoodLog? = nil,
        selectedDay: Date,
        mealType: MealType = .lunch,
        draft: FoodEntryDraft? = nil
    ) {
        self.existingLog = existingLog
        self.selectedDay = selectedDay
        self.mealType = existingLog?.mealType ?? mealType
        _selectedMeal = State(initialValue: existingLog?.mealType ?? mealType)

        if let existingLog {
            _name = State(initialValue: existingLog.displayName)
            _brand = State(initialValue: existingLog.brand ?? "")
            _calories = State(initialValue: NutritionRounding.caloriesText(existingLog.calories))
            _protein = State(initialValue: NutritionRounding.macroText(existingLog.proteinGrams))
            _carbs = State(initialValue: NutritionRounding.macroText(existingLog.carbsGrams))
            _fat = State(initialValue: NutritionRounding.macroText(existingLog.fatGrams))
            _fiber = State(initialValue: existingLog.fiberGrams.map { NutritionRounding.macroText($0) } ?? "")
            _amountText = State(initialValue: ServingPortionMath.formattedAmount(existingLog.quantity))
            _selectedUnit = State(initialValue: FoodServingUnit.parse(existingLog.unit))
            sourceType = existingLog.sourceType
            sourceFoodID = existingLog.sourceFoodID
            isEstimated = existingLog.isEstimated
            draftServingDescription = existingLog.unit
            gramsPerServing = ServingPortionMath.inferredGramsPerServing(
                weightGrams: existingLog.weightGrams,
                servingText: existingLog.unit
            )
            draftBarcode = nil
            draftSugar = existingLog.sugarGrams
            draftSodium = existingLog.sodiumMilligrams
            baselineCalories = existingLog.calories
            baselineProtein = existingLog.proteinGrams
            baselineCarbs = existingLog.carbsGrams
            baselineFat = existingLog.fatGrams
            baselineFiber = existingLog.fiberGrams
            referenceAmount = existingLog.quantity > 0 ? existingLog.quantity : 1
            referenceUnit = FoodServingUnit.parse(existingLog.unit)
        } else if let draft {
            _name = State(initialValue: draft.name)
            _brand = State(initialValue: draft.brand ?? "")
            _calories = State(initialValue: NutritionRounding.caloriesText(draft.calories))
            _protein = State(initialValue: NutritionRounding.macroText(draft.proteinGrams))
            _carbs = State(initialValue: NutritionRounding.macroText(draft.carbsGrams))
            _fat = State(initialValue: NutritionRounding.macroText(draft.fatGrams))
            _fiber = State(initialValue: draft.fiberGrams.map { NutritionRounding.macroText($0) } ?? "")
            _amountText = State(initialValue: ServingPortionMath.formattedAmount(draft.quantity))
            _selectedUnit = State(initialValue: .serving)
            sourceType = draft.sourceType
            sourceFoodID = draft.sourceFoodID
            isEstimated = draft.isEstimated
            draftServingDescription = draft.servingDescription
            gramsPerServing = ServingPortionMath.inferredGramsPerServing(
                weightGrams: draft.servingWeightGrams,
                servingText: draft.servingDescription
            )
            draftBarcode = draft.barcode
            draftSugar = draft.sugarGrams
            draftSodium = draft.sodiumMilligrams
            baselineCalories = draft.calories
            baselineProtein = draft.proteinGrams
            baselineCarbs = draft.carbsGrams
            baselineFat = draft.fatGrams
            baselineFiber = draft.fiberGrams
            referenceAmount = draft.quantity > 0 ? draft.quantity : 1
            referenceUnit = .serving
        } else {
            sourceType = .manual
            sourceFoodID = nil
            isEstimated = false
            draftServingDescription = nil
            gramsPerServing = nil
            draftBarcode = nil
            draftSugar = nil
            draftSodium = nil
            baselineCalories = 0
            baselineProtein = 0
            baselineCarbs = 0
            baselineFat = 0
            baselineFiber = nil
            referenceAmount = 1
            referenceUnit = .serving
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Double(calories) ?? -1) >= 0
    }

    private var title: String {
        if existingLog != nil { return "Edit Food" }
        if sourceType == .manual { return "Manual Entry" }
        return "Log Food"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        labeledField("Food", text: $name, placeholder: "Chicken breast")
                        labeledField("Brand", text: $brand, placeholder: "Optional")

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

                        servingRow

                        labeledField("Calories", text: $calories, placeholder: "0", keyboard: .decimalPad)
                        HStack(spacing: 10) {
                            labeledField("Protein (g)", text: $protein, placeholder: "0", keyboard: .decimalPad)
                            labeledField("Carbs (g)", text: $carbs, placeholder: "0", keyboard: .decimalPad)
                            labeledField("Fat (g)", text: $fat, placeholder: "0", keyboard: .decimalPad)
                        }
                        labeledField("Fiber (g)", text: $fiber, placeholder: "0", keyboard: .decimalPad)

                        if sourceType != .manual {
                            Text(isEstimated ? "\(sourceType.displayName) — confirm portions before logging." : sourceType.displayName)
                                .font(.appCaption)
                                .foregroundColor(.appTextTertiary)
                        }
                        if let draftBarcode, !draftBarcode.isEmpty {
                            Text("Barcode \(draftBarcode)")
                                .font(.appCaption)
                                .foregroundColor(.appTextTertiary)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(title)
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
            .onChange(of: amountText) { _, _ in
                applyServingScale()
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appCanvas)
    }

    private var availableUnits: [FoodServingUnit] {
        if let gramsPerServing, gramsPerServing > 0 {
            return FoodServingUnit.allCases
        }
        return [.serving]
    }

    private var servingHint: String? {
        guard let gramsPerServing, gramsPerServing > 0 else {
            return draftServingDescription
        }
        if selectedUnit == .serving {
            return "1 serving = \(ServingPortionMath.formattedAmount(gramsPerServing)) g"
        }
        if selectedUnit != .gram {
            return "\(ServingPortionMath.formattedAmount(gramsPerServing)) g per serving"
        }
        return nil
    }

    private var servingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Serving")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            HStack(spacing: 10) {
                TextField("1", text: $amountText)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.appTextPrimary)
                    .appInputSurface()
                    .frame(maxWidth: 120)
                Menu {
                    ForEach(availableUnits) { unit in
                        Button(unit.menuTitle) {
                            changeUnit(to: unit)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedUnit.menuTitle)
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appTextTertiary)
                    }
                    .appInputSurface()
                }
            }
            if let servingHint, !servingHint.isEmpty {
                Text(servingHint)
                    .font(.appCaption)
                    .foregroundColor(.appTextTertiary)
            }
            Text(liveMacrosLine)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
        }
    }

    private var liveMacrosLine: String {
        NutritionRounding.macrosCaption(
            calories: Double(calories) ?? 0,
            protein: Double(protein) ?? 0,
            carbs: Double(carbs) ?? 0,
            fat: Double(fat) ?? 0,
            fiber: fiber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Double(fiber)
        )
    }

    private func changeUnit(to unit: FoodServingUnit) {
        guard unit != selectedUnit else { return }
        let currentAmount = Double(amountText) ?? referenceAmount
        if let currentGrams = ServingPortionMath.grams(
            amount: currentAmount,
            unit: selectedUnit,
            gramsPerServing: gramsPerServing
        ), let converted = ServingPortionMath.amount(
            grams: currentGrams,
            unit: unit,
            gramsPerServing: gramsPerServing
        ) {
            selectedUnit = unit
            amountText = ServingPortionMath.formattedAmount(converted)
        } else {
            selectedUnit = unit
        }
        applyServingScale()
    }

    private func applyServingScale() {
        guard baselineCalories > 0 || baselineProtein > 0 || baselineCarbs > 0 || baselineFat > 0 else {
            return
        }
        let amount = Double(amountText) ?? 0
        let factor = ServingPortionMath.factor(
            referenceAmount: referenceAmount,
            referenceUnit: referenceUnit,
            amount: amount,
            unit: selectedUnit,
            gramsPerServing: gramsPerServing
        )
        calories = NutritionRounding.caloriesText(baselineCalories * factor)
        protein = NutritionRounding.macroText(baselineProtein * factor)
        carbs = NutritionRounding.macroText(baselineCarbs * factor)
        fat = NutritionRounding.macroText(baselineFat * factor)
        if let baselineFiber {
            fiber = NutritionRounding.macroText(baselineFiber * factor)
        }
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
        let trimmedName = FoodNameFormatting.displayName(name)
        let caloriesValue = NutritionRounding.calories(Double(calories) ?? 0)
        let proteinValue = NutritionRounding.macro(Double(protein) ?? 0)
        let carbsValue = NutritionRounding.macro(Double(carbs) ?? 0)
        let fatValue = NutritionRounding.macro(Double(fat) ?? 0)
        let fiberValue = fiber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : NutritionRounding.macro(Double(fiber) ?? 0)
        let quantityValue = NutritionRounding.serving(max(Double(amountText) ?? 1, 0))
        let factor = ServingPortionMath.factor(
            referenceAmount: referenceAmount,
            referenceUnit: referenceUnit,
            amount: quantityValue,
            unit: selectedUnit,
            gramsPerServing: gramsPerServing
        )
        let brandValue = FoodNameFormatting.optionalDisplayName(brand)
        let scaledSugar = draftSugar.map { NutritionRounding.macro($0 * factor) }
        let scaledSodium = draftSodium.map { NutritionRounding.macro($0 * factor) }
        let loggedAt: Date = {
            if Calendar.current.isDate(selectedDay, inSameDayAs: .now) {
                return existingLog?.loggedAt ?? .now
            }
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDay) ?? selectedDay
        }()

        if let existingLog {
            existingLog.displayName = trimmedName
            existingLog.brand = brandValue
            existingLog.mealType = selectedMeal
            existingLog.calories = caloriesValue
            existingLog.proteinGrams = proteinValue
            existingLog.carbsGrams = carbsValue
            existingLog.fatGrams = fatValue
            existingLog.fiberGrams = fiberValue
            existingLog.quantity = quantityValue
            existingLog.unit = selectedUnit.storageLabel
            existingLog.weightGrams = gramsPerServing ?? existingLog.weightGrams
            existingLog.sugarGrams = scaledSugar ?? existingLog.sugarGrams
            existingLog.sodiumMilligrams = scaledSodium ?? existingLog.sodiumMilligrams
            existingLog.loggedAt = loggedAt
        } else {
            let log = FoodLog(
                loggedAt: loggedAt,
                mealType: selectedMeal,
                sourceType: sourceType,
                sourceFoodID: sourceFoodID,
                displayName: trimmedName,
                brand: brandValue,
                quantity: quantityValue,
                unit: selectedUnit.storageLabel,
                weightGrams: gramsPerServing,
                calories: caloriesValue,
                proteinGrams: proteinValue,
                carbsGrams: carbsValue,
                fatGrams: fatValue,
                fiberGrams: fiberValue,
                sugarGrams: scaledSugar,
                sodiumMilligrams: scaledSodium,
                isEstimated: isEstimated
            )
            modelContext.insert(log)
            upsertCustomFood(
                name: trimmedName,
                brand: brandValue,
                calories: baselineCalories > 0 ? baselineCalories : caloriesValue,
                protein: baselineProtein > 0 ? baselineProtein : proteinValue,
                carbs: baselineCarbs > 0 ? baselineCarbs : carbsValue,
                fat: baselineFat > 0 ? baselineFat : fatValue,
                fiber: baselineFiber ?? fiberValue
            )
        }

        try? modelContext.save()
        NutritionBackupService.shared.markDirty()
        dismiss()
    }

    private func upsertCustomFood(
        name: String,
        brand: String?,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double?
    ) {
        let descriptor = FetchDescriptor<CustomFood>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if let match = existing.first(where: {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                && ($0.brand ?? "") == (brand ?? "")
        }) {
            match.calories = calories
            match.proteinGrams = protein
            match.carbsGrams = carbs
            match.fatGrams = fat
            match.fiberGrams = fiber ?? match.fiberGrams
            match.sugarGrams = draftSugar ?? match.sugarGrams
            match.sodiumMilligrams = draftSodium ?? match.sodiumMilligrams
            match.barcode = draftBarcode ?? match.barcode
            match.servingDescription = draftServingDescription ?? match.servingDescription
            match.servingWeightGrams = gramsPerServing ?? match.servingWeightGrams
            match.lastUsedAt = .now
            return
        }

        let food = CustomFood(
            name: name,
            brand: brand,
            barcode: draftBarcode,
            servingDescription: draftServingDescription ?? "1 serving",
            servingWeightGrams: gramsPerServing,
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            fiberGrams: fiber,
            sugarGrams: draftSugar,
            sodiumMilligrams: draftSodium,
            lastUsedAt: .now
        )
        modelContext.insert(food)
    }
}
