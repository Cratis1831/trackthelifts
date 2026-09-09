import XCTest
@testable import trackthelifts

final class SubscriptionAccessPolicyTests: XCTestCase {
    func testAllProFeaturesRequireProTier() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(SubscriptionAccessPolicy.canAccess(feature, tier: .free))
            XCTAssertTrue(SubscriptionAccessPolicy.canAccess(feature, tier: .pro))
        }
    }

    func testTrialIncludesEveryNutritionFeature() {
        XCTAssertEqual(ProFeature.trialIncluded, ProFeature.merchandised)
        XCTAssertFalse(ProFeature.merchandised.contains(.foodPhoto))
        XCTAssertTrue(ProFeature.merchandised.contains(.labelScan))
        for feature in ProFeature.merchandised {
            XCTAssertTrue(feature.isIncludedInFreeTrial)
            XCTAssertTrue(
                SubscriptionAccessPolicy.canAccess(feature, tier: .pro, isInFreeTrial: true),
                "\(feature.title) should be available during the trial"
            )
        }
    }

    func testRoutinesAreUnlimitedForFreeAndPro() {
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 0, tier: .free))
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 10, tier: .free))
        XCTAssertTrue(SubscriptionAccessPolicy.canCreateRoutine(existingCount: 10, tier: .pro))
        XCTAssertTrue(SubscriptionAccessPolicy.canCopyRoutineSource(
            existingCount: 20,
            sourceContainsSupersets: true,
            tier: .free
        ))
    }

    func testDebugOverrideWinsOverEntitlement() {
        XCTAssertEqual(
            SubscriptionAccessPolicy.effectiveTier(entitlementTier: .pro, debugOverride: nil),
            .pro
        )
        XCTAssertEqual(
            SubscriptionAccessPolicy.effectiveTier(entitlementTier: .pro, debugOverride: .free),
            .free
        )
        XCTAssertEqual(
            SubscriptionAccessPolicy.effectiveTier(entitlementTier: .free, debugOverride: .pro),
            .pro
        )
    }

    func testPaidThemeIsAvailableWithoutPro() {
        let selectedTheme = AppTheme.purple

        XCTAssertEqual(
            ThemeAccessPolicy.effectiveTheme(selectedTheme: selectedTheme, hasProAccess: false),
            .purple
        )
        XCTAssertEqual(
            ThemeAccessPolicy.effectiveTheme(selectedTheme: selectedTheme, hasProAccess: true),
            .purple
        )
    }

    func testEffortTrackingIsAvailableWithoutPro() {
        let selectedMode = IntensityPreferenceMode.rpe

        XCTAssertEqual(
            IntensityAccessPolicy.effectiveMode(selectedMode: selectedMode, hasProAccess: false),
            .rpe
        )
        XCTAssertEqual(
            IntensityAccessPolicy.effectiveMode(selectedMode: selectedMode, hasProAccess: true),
            .rpe
        )
    }

    func testRestTimerFormattingClampsAndPadsSeconds() {
        XCTAssertEqual(RestTimerPresentation.formattedTime(-1), "0:00")
        XCTAssertEqual(RestTimerPresentation.formattedTime(5), "0:05")
        XCTAssertEqual(RestTimerPresentation.formattedTime(90), "1:30")
        XCTAssertEqual(RestTimerPresentation.formattedTime(300), "5:00")
    }

    func testRestTimerProgressUsesConfiguredDurationAndClampsBounds() {
        XCTAssertEqual(RestTimerPresentation.progress(remaining: 45, totalDuration: 90), 0.5)
        XCTAssertEqual(RestTimerPresentation.progress(remaining: -1, totalDuration: 90), 0)
        XCTAssertEqual(RestTimerPresentation.progress(remaining: 120, totalDuration: 90), 1)
        XCTAssertEqual(RestTimerPresentation.progress(remaining: 30, totalDuration: 0), 0)
    }

    func testOnboardingFlowHasTenOrderedPages() {
        XCTAssertEqual(OnboardingPage.allCases.count, 10)
        XCTAssertEqual(OnboardingPage.welcome.next, .workouts)
        XCTAssertEqual(OnboardingPage.workouts.next, .routines)
        XCTAssertEqual(OnboardingPage.routines.next, .progress)
        XCTAssertEqual(OnboardingPage.progress.next, .personalization)
        XCTAssertEqual(OnboardingPage.personalization.next, .ready)
        XCTAssertEqual(OnboardingPage.ready.next, .nutritionDiary)
        XCTAssertEqual(OnboardingPage.nutritionDiary.next, .nutritionLogging)
        XCTAssertEqual(OnboardingPage.nutritionLogging.next, .trial)
        XCTAssertEqual(OnboardingPage.trial.next, .profile)
        XCTAssertNil(OnboardingPage.profile.next)
        XCTAssertTrue(OnboardingPage.profile.isFinal)
        XCTAssertFalse(OnboardingPage.trial.isFinal)
        XCTAssertFalse(OnboardingPage.ready.isFinal)
    }

    func testOnboardingSkipRoutesToNutritionThenProfile() {
        XCTAssertEqual(OnboardingPage.skipDestination, .nutritionDiary)
    }

    func testProfileNamePolicyNormalizesAndValidatesNames() {
        XCTAssertEqual(ProfileNamePolicy.normalized("  Ashkan Sotoudeh\n"), "Ashkan Sotoudeh")
        XCTAssertTrue(ProfileNamePolicy.isValid(" Ashkan "))
        XCTAssertFalse(ProfileNamePolicy.isValid("  \n\t "))
    }

    func testProfileNamePolicyBuildsAvatarInitials() {
        XCTAssertEqual(ProfileNamePolicy.initials(from: "Ashkan"), "A")
        XCTAssertEqual(ProfileNamePolicy.initials(from: "Ashkan Sotoudeh"), "AS")
        XCTAssertEqual(ProfileNamePolicy.initials(from: "Ashkan Reza Sotoudeh"), "AS")
        XCTAssertNil(ProfileNamePolicy.initials(from: "  "))
    }

    func testPlanKindFallsBackToProductIdentifier() {
        XCTAssertEqual(
            SubscriptionPlanKind.from(packageTypeDescription: "custom", productIdentifier: "com.app.Monthly"),
            .monthly
        )
        XCTAssertEqual(
            SubscriptionPlanKind.from(packageTypeDescription: "annual", productIdentifier: "ignored"),
            .annual
        )
        XCTAssertEqual(SubscriptionPlanKind.from(productIdentifier: "com.app.lifetime"), .lifetime)
        XCTAssertEqual(SubscriptionPlanKind.annual.displayName, "Yearly")
    }

    func testFreeTrialCopyMatchesAppleDisclosureNeeds() {
        let weeklyTrial = IntroOfferSummary(
            paymentMode: .freeTrial,
            periodCount: 1,
            periodUnit: .week
        )

        XCTAssertEqual(SubscriptionOfferPresentation.durationPhrase(for: weeklyTrial), "1 week")
        XCTAssertEqual(SubscriptionOfferPresentation.hyphenatedDuration(for: weeklyTrial), "1-Week")
        XCTAssertEqual(SubscriptionOfferPresentation.trialCardCaption(for: weeklyTrial), "1 week free")
        XCTAssertEqual(
            SubscriptionOfferPresentation.purchaseButtonTitle(
                plan: .monthly,
                price: "$1.99",
                intro: weeklyTrial,
                isIntroEligible: true
            ),
            "Start 1-Week Free Trial"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.trialRenewalCaption(price: "$39.99", plan: .annual),
            "then $39.99/year"
        )

        let threeDayTrial = IntroOfferSummary(
            paymentMode: .freeTrial,
            periodCount: 3,
            periodUnit: .day
        )
        XCTAssertEqual(SubscriptionOfferPresentation.trialCardCaption(for: threeDayTrial), "3 days free")
        XCTAssertEqual(
            SubscriptionOfferPresentation.purchaseButtonTitle(
                plan: .annual,
                price: "$39.99",
                intro: threeDayTrial,
                isIntroEligible: true
            ),
            "Start 3-Day Free Trial"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.legalFooter(
                plan: .annual,
                price: "$39.99",
                intro: threeDayTrial,
                isIntroEligible: true
            ),
            "Free for 3 days, then $39.99/year. Cancel anytime in Settings at least 24 hours before the trial ends."
        )
    }

    func testIneligibleAndLifetimeCopyStayPaid() {
        let weeklyTrial = IntroOfferSummary(
            paymentMode: .freeTrial,
            periodCount: 1,
            periodUnit: .week
        )

        XCTAssertEqual(
            SubscriptionOfferPresentation.purchaseButtonTitle(
                plan: .monthly,
                price: "$1.99",
                intro: weeklyTrial,
                isIntroEligible: false
            ),
            "Start Pro - $1.99"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.purchaseButtonTitle(
                plan: .lifetime,
                price: "$24.99",
                intro: nil,
                isIntroEligible: false
            ),
            "Get Lifetime Access - $24.99"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.legalFooter(
                plan: .lifetime,
                price: "$24.99",
                intro: nil,
                isIntroEligible: false
            ),
            "One-time purchase. No subscription, no renewals."
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.settingsUpgradeTitle(isMonthlyTrialEligible: true),
            "Try Pro Free"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.settingsUpgradeTitle(isMonthlyTrialEligible: false),
            "Upgrade to Pro"
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.settingsUpgradeTitle(
                isMonthlyTrialEligible: false,
                isAnnualTrialEligible: true
            ),
            "Try Pro Free"
        )
    }

    func testYearlySavingsPercentUsesLocalMonthlyVersusAnnualPrices() {
        XCTAssertEqual(
            SubscriptionOfferPresentation.yearlySavingsPercent(
                monthlyPrice: Decimal(string: "5.99")!,
                annualPrice: Decimal(string: "39.99")!
            ),
            44
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.yearlySavingsPercent(
                monthlyPrice: Decimal(string: "12.90")!,
                annualPrice: Decimal(string: "69.90")!
            ),
            55
        )
        XCTAssertEqual(
            SubscriptionOfferPresentation.yearlySavingsPercent(
                monthlyPrice: Decimal(string: "499")!,
                annualPrice: Decimal(string: "3999")!
            ),
            33
        )
        XCTAssertNil(
            SubscriptionOfferPresentation.yearlySavingsPercent(
                monthlyPrice: Decimal(string: "5.99")!,
                annualPrice: Decimal(string: "79.99")!
            )
        )
        XCTAssertNil(
            SubscriptionOfferPresentation.yearlySavingsPercent(monthlyPrice: 0, annualPrice: 39.99)
        )
    }
}

final class NutritionAccessPolicyTests: XCTestCase {
    func testFreeManualLogLimit() {
        XCTAssertTrue(NutritionAccessPolicy.canLogManually(existingLogCount: 0, tier: .free))
        XCTAssertTrue(NutritionAccessPolicy.canLogManually(existingLogCount: 2, tier: .free))
        XCTAssertFalse(NutritionAccessPolicy.canLogManually(existingLogCount: 3, tier: .free))
        XCTAssertTrue(NutritionAccessPolicy.canLogManually(existingLogCount: 30, tier: .pro))
        XCTAssertEqual(
            NutritionAccessPolicy.remainingFreeLogs(existingLogCount: 1, tier: .free),
            2
        )
        XCTAssertNil(NutritionAccessPolicy.remainingFreeLogs(existingLogCount: 1, tier: .pro))
    }

    func testDashboardPreviewIsFreeAndAdvancedEntryIsPro() {
        XCTAssertTrue(NutritionAccessPolicy.canUseAdvancedEntry(.calorieTracking, tier: .free))
        XCTAssertFalse(NutritionAccessPolicy.canUseAdvancedEntry(.barcodeScan, tier: .free))
        XCTAssertFalse(NutritionAccessPolicy.canUseAdvancedEntry(.aiDescribe, tier: .free))
        XCTAssertFalse(NutritionAccessPolicy.canUseAdvancedEntry(.labelScan, tier: .free))
        XCTAssertTrue(NutritionAccessPolicy.canUseAdvancedEntry(.labelScan, tier: .pro))
    }

    func testNutritionTotalsSnapshot() {
        let chicken = FoodLog(
            mealType: .lunch,
            displayName: "Chicken",
            calories: 190,
            proteinGrams: 35,
            carbsGrams: 0,
            fatGrams: 4,
            fiberGrams: 2
        )
        let rice = FoodLog(
            mealType: .lunch,
            displayName: "Rice",
            calories: 200,
            proteinGrams: 4,
            carbsGrams: 45,
            fatGrams: 1,
            fiberGrams: 1
        )
        let totals = NutritionMath.totals(from: [chicken, rice])
        XCTAssertEqual(totals.calories, 390)
        XCTAssertEqual(totals.proteinGrams, 39)
        XCTAssertEqual(totals.carbsGrams, 45)
        XCTAssertEqual(totals.fatGrams, 5)
        XCTAssertEqual(totals.fiberGrams, 3)
    }

    func testHalfServingScalesCaloriesAndMacros() {
        let factor = ServingPortionMath.factor(
            referenceAmount: 1,
            referenceUnit: .serving,
            amount: 0.5,
            unit: .serving,
            gramsPerServing: 100
        )
        XCTAssertEqual(factor, 0.5)
        XCTAssertEqual(
            ServingPortionMath.grams(amount: 0.5, unit: .serving, gramsPerServing: 100) ?? 0,
            50,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ServingPortionMath.factor(
                referenceAmount: 100,
                referenceUnit: .gram,
                amount: 50,
                unit: .gram,
                gramsPerServing: 100
            ),
            0.5
        )
        let ouncesGrams = ServingPortionMath.grams(amount: 1, unit: .ounce, gramsPerServing: nil) ?? 0
        XCTAssertEqual(ouncesGrams, ServingPortionMath.gramsPerOunce, accuracy: 0.0001)
    }

    func testServingUnitConversionKeepsGrams() {
        let grams = ServingPortionMath.grams(amount: 100, unit: .gram, gramsPerServing: 100)!
        let ounces = ServingPortionMath.amount(grams: grams, unit: .ounce, gramsPerServing: 100)!
        let back = ServingPortionMath.grams(amount: ounces, unit: .ounce, gramsPerServing: 100)!
        XCTAssertEqual(grams, back, accuracy: 0.0001)
        XCTAssertEqual(FoodServingUnit.parse("serving"), .serving)
        XCTAssertEqual(FoodServingUnit.parse("g"), .gram)
        XCTAssertEqual(ServingPortionMath.grams(fromServingText: "30g (1 oz)"), 30)
        XCTAssertEqual(FoodServingUnit.parse("100 g"), .serving)
        XCTAssertEqual(ServingPortionMath.grams(fromServingText: "100 g"), 100)
        XCTAssertEqual(ServingPortionMath.grams(fromServingText: "1 bar (60 g)"), 60)
        XCTAssertEqual(
            ServingPortionMath.inferredGramsPerServing(weightGrams: nil, servingText: "100 g"),
            100
        )
        XCTAssertEqual(
            ServingPortionMath.inferredGramsPerServing(weightGrams: 40, servingText: "100 g"),
            40
        )
        XCTAssertNil(ServingPortionMath.grams(fromServingText: "1 cup"))
    }

    func testNutritionRoundingLimitsDecimals() {
        XCTAssertEqual(NutritionRounding.calories(199.4), 199)
        XCTAssertEqual(NutritionRounding.calories(199.5), 200)
        XCTAssertEqual(NutritionRounding.macro(12.34), 12)
        XCTAssertEqual(NutritionRounding.macro(12.5), 13)
        XCTAssertEqual(NutritionRounding.serving(1.23456789), 1.23457)
        XCTAssertEqual(NutritionRounding.caloriesText(199.6), "200")
        XCTAssertEqual(NutritionRounding.macroText(31), "31")
        XCTAssertEqual(NutritionRounding.macroText(31.4), "31")
        XCTAssertEqual(NutritionRounding.servingText(28.349523125), "28.34952")
        XCTAssertEqual(
            NutritionRounding.macrosCaption(
                calories: 247.4,
                protein: 21.25,
                carbs: 2,
                fat: 7.14,
                fiber: 3.05
            ),
            "247 kcal · P 21 · C 2 · F 7 · Fi 3"
        )
    }

    func testMacroEnergyUsesFourFourNine() {
        let grams = MacroEnergy.grams(
            calories: 2000,
            proteinPercent: 40,
            carbPercent: 40,
            fatPercent: 20
        )
        XCTAssertEqual(grams.protein, 200)
        XCTAssertEqual(grams.carbs, 200)
        XCTAssertEqual(grams.fat, 44)
        XCTAssertEqual(
            MacroEnergy.calories(proteinGrams: 200, carbsGrams: 200, fatGrams: 44),
            1996
        )

        let percents = MacroEnergy.percents(proteinGrams: 200, carbsGrams: 200, fatGrams: 44)
        XCTAssertEqual(percents.protein, 40)
        XCTAssertEqual(percents.carbs, 40)
        XCTAssertEqual(percents.fat, 20)

        let split = MacroEnergy.resolved(
            calories: 2123,
            proteinPercent: 40,
            carbPercent: 40,
            fatPercent: 20
        )
        XCTAssertEqual(split.protein, 212)
        XCTAssertEqual(split.carbs, 212)
        XCTAssertEqual(split.fat, 47)
        XCTAssertEqual(split.calories, 2119)
    }

    func testServingUnitConversionKeepsGramsAndDisplayRounding() {
        let ouncesGrams = ServingPortionMath.grams(amount: 1, unit: .ounce, gramsPerServing: nil) ?? 0
        XCTAssertEqual(ouncesGrams, ServingPortionMath.gramsPerOunce, accuracy: 0.000000001)
        XCTAssertEqual(
            ServingPortionMath.grams(amount: 1, unit: .pound, gramsPerServing: nil) ?? 0,
            ServingPortionMath.gramsPerPound,
            accuracy: 0.000000001
        )
        XCTAssertEqual(
            ServingPortionMath.grams(amount: 1, unit: .kilogram, gramsPerServing: nil) ?? 0,
            1000,
            accuracy: 0.000000001
        )

        let grams = ServingPortionMath.grams(amount: 100, unit: .gram, gramsPerServing: 100)!
        let ounces = ServingPortionMath.amount(grams: grams, unit: .ounce, gramsPerServing: 100)!
        let back = ServingPortionMath.grams(amount: ounces, unit: .ounce, gramsPerServing: 100)!
        XCTAssertEqual(grams, back, accuracy: 0.0000001)
        XCTAssertEqual(
            ServingPortionMath.factor(
                referenceAmount: 100,
                referenceUnit: .gram,
                amount: 3.5274,
                unit: .ounce,
                gramsPerServing: 100
            ),
            1,
            accuracy: 0.001
        )
    }

    func testHalfServingScalesThenRoundsForDisplay() {
        let factor = ServingPortionMath.factor(
            referenceAmount: 1,
            referenceUnit: .serving,
            amount: 0.5,
            unit: .serving,
            gramsPerServing: 100
        )
        XCTAssertEqual(factor, 0.5)
        XCTAssertEqual(NutritionRounding.calories(247 * factor), 124)
        XCTAssertEqual(NutritionRounding.macro(21.3 * factor), 11)
        XCTAssertEqual(NutritionRounding.serving(0.5), 0.5)
    }

    func testMealCopyLookbackSkipsTheCurrentMeal() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents(year: 2026, month: 9, day: 9, hour: 12)
        let today = calendar.date(from: components)!
        components.day = 8
        let yesterday = calendar.date(from: components)!
        let todayLunch = FoodLog(loggedAt: today, mealType: .lunch, displayName: "Today", calories: 100, proteinGrams: 1, carbsGrams: 1, fatGrams: 1)
        let yesterdayLunch = FoodLog(loggedAt: yesterday, mealType: .lunch, displayName: "Yesterday lunch", calories: 400, proteinGrams: 30, carbsGrams: 10, fatGrams: 8)
        let yesterdayDinner = FoodLog(loggedAt: yesterday, mealType: .dinner, displayName: "Yesterday dinner", calories: 600, proteinGrams: 40, carbsGrams: 20, fatGrams: 15)

        let sources = MealCopying.sources(
            from: [todayLunch, yesterdayLunch, yesterdayDinner],
            relativeTo: today,
            excluding: .lunch,
            calendar: calendar
        )
        XCTAssertEqual(sources.map(\.meal), [.lunch, .dinner])
        XCTAssertEqual(sources.first?.calories, 400)

        let copies = MealCopying.copy([yesterdayLunch], to: .breakfast, on: today, now: today, calendar: calendar)
        XCTAssertEqual(copies.count, 1)
        XCTAssertEqual(copies[0].mealType, .breakfast)
        XCTAssertEqual(copies[0].displayName, "Yesterday lunch")
        XCTAssertEqual(copies[0].calories, 400)
        XCTAssertNotEqual(copies[0].id, yesterdayLunch.id)
    }
}
