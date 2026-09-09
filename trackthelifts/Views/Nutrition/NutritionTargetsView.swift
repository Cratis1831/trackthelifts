//
//  NutritionTargetsView.swift
//  TrackTheLifts
//

import SwiftUI

private enum MacroSplitKind: String, CaseIterable, Identifiable {
    case percent
    case grams

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percent: return "Percent"
        case .grams: return "Grams"
        }
    }

    var detail: String {
        switch self {
        case .percent:
            return "Split calories across protein, carbs, and fat. The three must add to 100%."
        case .grams:
            return "Set protein, carbs, and fat in grams. Calories stay the budget you entered."
        }
    }
}

struct NutritionTargetsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targets = NutritionPreference.shared
    @State private var mode: MacroSplitKind?
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String
    @State private var proteinPercent: String
    @State private var carbPercent: String
    @State private var fatPercent: String

    init() {
        let preference = NutritionPreference.shared
        _calories = State(initialValue: preference.calories > 0 ? NutritionRounding.caloriesText(preference.calories) : "")
        _protein = State(initialValue: preference.proteinGrams > 0 ? NutritionRounding.macroText(preference.proteinGrams) : "")
        _carbs = State(initialValue: preference.carbsGrams > 0 ? NutritionRounding.macroText(preference.carbsGrams) : "")
        _fat = State(initialValue: preference.fatGrams > 0 ? NutritionRounding.macroText(preference.fatGrams) : "")
        _fiber = State(initialValue: preference.fiberGrams > 0 ? NutritionRounding.macroText(preference.fiberGrams) : "")

        let percents = MacroEnergy.percents(
            proteinGrams: preference.proteinGrams,
            carbsGrams: preference.carbsGrams,
            fatGrams: preference.fatGrams
        )
        _proteinPercent = State(initialValue: NutritionRounding.macroText(percents.protein))
        _carbPercent = State(initialValue: NutritionRounding.macroText(percents.carbs))
        _fatPercent = State(initialValue: NutritionRounding.macroText(percents.fat))
        _mode = State(initialValue: preference.hasSetTargets ? .percent : nil)
    }

    private var enteredCalories: Double {
        NutritionRounding.calories(Double(calories) ?? 0)
    }

    private var hasCalories: Bool {
        enteredCalories > 0
    }

    private var percentTotal: Double {
        (Double(proteinPercent) ?? 0) + (Double(carbPercent) ?? 0) + (Double(fatPercent) ?? 0)
    }

    private var percentsAddTo100: Bool {
        abs(percentTotal - 100) < 0.5
    }

    private var percentSplit: (protein: Double, carbs: Double, fat: Double, calories: Double) {
        MacroEnergy.resolved(
            calories: enteredCalories,
            proteinPercent: Double(proteinPercent) ?? 0,
            carbPercent: Double(carbPercent) ?? 0,
            fatPercent: Double(fatPercent) ?? 0
        )
    }

    private var gramCalories: Double {
        MacroEnergy.calories(
            proteinGrams: Double(protein) ?? 0,
            carbsGrams: Double(carbs) ?? 0,
            fatGrams: Double(fat) ?? 0
        )
    }

    private var gramPercents: (protein: Double, carbs: Double, fat: Double) {
        MacroEnergy.percents(
            proteinGrams: Double(protein) ?? 0,
            carbsGrams: Double(carbs) ?? 0,
            fatGrams: Double(fat) ?? 0
        )
    }

    private var savedCalories: Double {
        switch mode {
        case .percent:
            return percentsAddTo100 ? percentSplit.calories : enteredCalories
        case .grams:
            return gramCalories > 0 ? gramCalories : enteredCalories
        case nil:
            return enteredCalories
        }
    }

    private var calorieNudgeNote: String? {
        let saved = savedCalories
        guard hasCalories, saved > 0, saved != enteredCalories else { return nil }
        let delta = abs(saved - enteredCalories)
        switch mode {
        case .percent:
            return "Whole-number grams land at \(NutritionRounding.caloriesText(saved)) kcal so the split stays exact. That’s \(NutritionRounding.caloriesText(delta)) kcal from \(NutritionRounding.caloriesText(enteredCalories))."
        case .grams:
            return "These grams are \(NutritionRounding.caloriesText(saved)) kcal. We’ll save that as your calorie target so it matches protein, carbs, and fat."
        case nil:
            return nil
        }
    }

    private var gramsRemainingNote: String? {
        guard mode == .grams, hasCalories, gramCalories > 0 else { return nil }
        let remaining = enteredCalories - gramCalories
        if remaining == 0 { return nil }
        if remaining > 0 {
            return "\(NutritionRounding.caloriesText(remaining)) kcal left to assign — about \(NutritionRounding.macroText(remaining / 4)) g protein or carbs, or \(NutritionRounding.macroText(remaining / 9)) g fat."
        }
        return "\(NutritionRounding.caloriesText(-remaining)) kcal over the locked total."
    }

    private var canSave: Bool {
        guard hasCalories, let mode else { return false }
        switch mode {
        case .percent:
            return percentsAddTo100
        case .grams:
            return gramCalories > 0
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("ForgeLyte Lift does not recommend calories or macros. This is not a medical, diet, or coaching app — only set targets you already have from a qualified professional or your own plan. These stay on this device and are not stored in iCloud.")
                            .font(.system(size: 13))
                            .foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        step1Calories
                        step2SplitKind
                        step3Macros
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Targets")
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

    private var step1Calories: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(1, title: "Daily calories", enabled: true)
            Text("Enter the calorie total you want to hit each day. Macros come next and will not rewrite this number as you type.")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            field("Calories", text: $calories)
        }
    }

    private var step2SplitKind: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(2, title: "Percent or grams", enabled: hasCalories)
            Text("Calories stay locked at \(hasCalories ? NutritionRounding.caloriesText(enteredCalories) : "—") kcal. Pick how you want to set protein, carbs, and fat.")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(MacroSplitKind.allCases) { option in
                    splitKindCard(option)
                }
            }
        }
        .opacity(hasCalories ? 1 : 0.4)
        .allowsHitTesting(hasCalories)
    }

    private var step3Macros: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(3, title: step3Title, enabled: mode != nil && hasCalories)

            if mode == .percent {
                Text("Protein, carbs, and fat must add to 100%. 1 g protein = 4 kcal, 1 g carb = 4 kcal, 1 g fat = 9 kcal.")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                lockedCaloriesRow
                field("Protein (%)", text: $proteinPercent)
                field("Carbs (%)", text: $carbPercent)
                field("Fat (%)", text: $fatPercent)
                field("Fiber (g)", text: $fiber)

                if percentsAddTo100, enteredCalories > 0 {
                    Text("That’s \(NutritionRounding.macroText(percentSplit.protein)) g protein, \(NutritionRounding.macroText(percentSplit.carbs)) g carbs, and \(NutritionRounding.macroText(percentSplit.fat)) g fat.")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Protein, carbs, and fat should add to 100%. Currently \(NutritionRounding.macroText(percentTotal))%.")
                        .font(.appCaption)
                        .foregroundColor(.appAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if mode == .grams {
                Text("Set grams for protein, carbs, and fat. 1 g protein = 4 kcal, 1 g carb = 4 kcal, 1 g fat = 9 kcal.")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                lockedCaloriesRow
                field("Protein (g)", text: $protein)
                field("Carbs (g)", text: $carbs)
                field("Fat (g)", text: $fat)
                field("Fiber (g)", text: $fiber)

                if gramCalories > 0 {
                    Text("That’s \(NutritionRounding.macroText(gramPercents.protein))% protein, \(NutritionRounding.macroText(gramPercents.carbs))% carbs, and \(NutritionRounding.macroText(gramPercents.fat))% fat · \(NutritionRounding.caloriesText(gramCalories)) kcal.")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let gramsRemainingNote {
                    Text(gramsRemainingNote)
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Choose percent or grams to unlock this step.")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }

            if let calorieNudgeNote {
                Text(calorieNudgeNote)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(mode != nil && hasCalories ? 1 : 0.4)
        .allowsHitTesting(mode != nil && hasCalories)
    }

    private var step3Title: String {
        switch mode {
        case .percent: return "Percent split"
        case .grams: return "Gram split"
        case nil: return "Macro split"
        }
    }

    private var lockedCaloriesRow: some View {
        HStack {
            Text("Calories")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            Spacer()
            Text("\(NutritionRounding.caloriesText(enteredCalories)) kcal")
                .font(.appMetric)
                .foregroundColor(.appTextPrimary)
            Text("Locked")
                .font(.appUtility)
                .tracking(0.6)
                .foregroundColor(.appTextTertiary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: AppDesign.controlHeight)
        .background(Color.appElevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesign.compactRadius, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 1)
        }
    }

    private func stepHeader(_ number: Int, title: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.appUtility)
                .foregroundColor(enabled ? Color.onAppAction : .appTextTertiary)
                .frame(width: 22, height: 22)
                .background(enabled ? Color.appAction : Color.appElevatedSurface)
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(enabled ? .appTextPrimary : .appTextTertiary)
        }
    }

    private func splitKindCard(_ option: MacroSplitKind) -> some View {
        let selected = mode == option
        return Button {
            choose(option)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(selected ? .appAccent : .appTextTertiary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                    Text(option.detail)
                        .font(.system(size: 13))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .appCard()
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .strokeBorder(selected ? Color.appAccent : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .foregroundColor(.appTextPrimary)
                .appInputSurface()
        }
    }

    private func choose(_ option: MacroSplitKind) {
        if mode == option { return }
        if option == .grams, percentsAddTo100, enteredCalories > 0 {
            let split = percentSplit
            protein = NutritionRounding.macroText(split.protein)
            carbs = NutritionRounding.macroText(split.carbs)
            fat = NutritionRounding.macroText(split.fat)
        } else if option == .percent {
            let percents = gramPercents
            proteinPercent = NutritionRounding.macroText(percents.protein)
            carbPercent = NutritionRounding.macroText(percents.carbs)
            fatPercent = NutritionRounding.macroText(percents.fat)
        }
        mode = option
    }

    private func save() {
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        switch mode {
        case .percent:
            let split = percentSplit
            proteinGrams = split.protein
            carbsGrams = split.carbs
            fatGrams = split.fat
        case .grams:
            proteinGrams = NutritionRounding.macro(Double(protein) ?? 0)
            carbsGrams = NutritionRounding.macro(Double(carbs) ?? 0)
            fatGrams = NutritionRounding.macro(Double(fat) ?? 0)
        case nil:
            return
        }

        targets.calories = NutritionRounding.calories(savedCalories)
        targets.proteinGrams = proteinGrams
        targets.carbsGrams = carbsGrams
        targets.fatGrams = fatGrams
        targets.fiberGrams = NutritionRounding.macro(Double(fiber) ?? 0)
        NutritionBackupService.shared.markDirty()
        dismiss()
    }
}
