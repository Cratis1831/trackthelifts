import XCTest
@testable import trackthelifts

final class ForgeLyteAPITests: XCTestCase {
    func testRemoteFoodDecodingUsesServerSourceTypes() throws {
        let json = """
        {
          "id": "USDA:123",
          "name": "Kirkland Signature Protein Bar",
          "brand": "Kirkland Signature",
          "barcode": "0000000000000",
          "serving": { "amount": 1, "unit": "bar", "weight_g": 60 },
          "nutrition": {
            "calories": 190,
            "protein_g": 21,
            "carbs_g": 22,
            "fat_g": 7,
            "fiber_g": 3,
            "sugar_g": 1,
            "sodium_mg": 140
          },
          "source": {
            "type": "OPEN_FOOD_FACTS",
            "external_id": "0000000000000",
            "estimated": false
          }
        }
        """.data(using: .utf8)!

        let food = try JSONDecoder().decode(RemoteFood.self, from: json)
        XCTAssertEqual(food.name, "Kirkland Signature Protein Bar")
        XCTAssertEqual(food.serving.weightGrams, 60)
        XCTAssertEqual(food.nutrition.proteinGrams, 21)
        XCTAssertEqual(food.sourceType, .openFoodFacts)
        XCTAssertEqual(food.draft.sourceType, .openFoodFacts)
        XCTAssertEqual(food.draft.calories, 190)
        XCTAssertEqual(food.listBrand, "Kirkland Signature")
        XCTAssertEqual(food.servingLabel, "bar")
        XCTAssertEqual(food.energyLabel, "190 kcal")
        XCTAssertEqual(food.macrosLabel, "P 21 · C 22 · F 7 · Fi 3")
        XCTAssertEqual(food.draft.servingWeightGrams, 60)
        XCTAssertEqual(food.sourceType.displayName, "Open Food Facts · ODbL")
    }

    func testAPISourceMapping() {
        XCTAssertEqual(FoodSourceType.fromAPI("USDA"), .usda)
        XCTAssertEqual(FoodSourceType.fromAPI("OPEN_FOOD_FACTS"), .openFoodFacts)
        XCTAssertEqual(FoodSourceType.fromAPI("AI_ESTIMATE"), .aiEstimate)
        XCTAssertEqual(FoodSourceType.fromAPI("LABEL_SCAN_CONTRIBUTION"), .labelScan)
        XCTAssertEqual(FoodSourceType.fromAPI("USER_CONTRIBUTION"), .userContribution)
    }

    func testDraftInfersGramsWhenServingIsLabeled100g() throws {
        let json = """
        {
          "id": "OPEN_FOOD_FACTS:03030406",
          "name": "Quaker",
          "brand": "Quaker",
          "barcode": "03030406",
          "serving": { "amount": 1, "unit": "100 g" },
          "nutrition": { "calories": 400, "protein_g": 11, "carbs_g": 75, "fat_g": 12, "fiber_g": 11 },
          "source": { "type": "OPEN_FOOD_FACTS", "external_id": "03030406", "estimated": false }
        }
        """.data(using: .utf8)!
        let food = try JSONDecoder().decode(RemoteFood.self, from: json)
        XCTAssertNil(food.serving.weightGrams)
        XCTAssertEqual(food.draft.servingWeightGrams, 100)
        XCTAssertEqual(food.draft.servingDescription, "100 g")
        XCTAssertEqual(food.servingLabel, "100 g")
    }

    func testDraftDoesNotInvent100gWhenServingWeightIsMissing() throws {
        let json = """
        {
          "id": "LABEL_SCAN:local",
          "name": "Scanned food",
          "brand": null,
          "barcode": null,
          "serving": { "amount": 1, "unit": "1 serving" },
          "nutrition": { "calories": 190, "protein_g": 21, "carbs_g": 22, "fat_g": 7 },
          "source": { "type": "LABEL_SCAN_CONTRIBUTION", "external_id": null, "estimated": false }
        }
        """.data(using: .utf8)!
        let food = try JSONDecoder().decode(RemoteFood.self, from: json)
        XCTAssertEqual(food.servingLabel, "1 serving")
        XCTAssertNil(food.draft.servingWeightGrams)
        XCTAssertEqual(food.draft.calories, 190)
    }

    func testBarcodeNormalizationIgnoresFormattingAndLeadingZeros() {
        XCTAssertEqual(Barcode.normalize(" 0123-4567-8901 "), "012345678901")
        XCTAssertTrue(Barcode.matches("012345678901", "12345678901"))
        XCTAssertTrue(Barcode.matches("0000000000000", "0000000000000"))
        XCTAssertFalse(Barcode.matches("012345678901", "999"))
        XCTAssertEqual(FoodEntryDraft.manualBarcode("012345678901").sourceType, .manual)
        XCTAssertEqual(FoodEntryDraft.manualBarcode("012345678901").barcode, "012345678901")
    }

    func testNutritionFactsGateRequiresALabelHeading() {
        XCTAssertTrue(
            NutritionFactsLabelGate.looksLikeNutritionFacts([
                "Nutrition Facts",
                "Serving size 1 bar (60g)",
                "Calories 190",
                "Protein 21g"
            ])
        )
        XCTAssertTrue(
            NutritionFactsLabelGate.looksLikeNutritionFacts([
                "Valeur nutritive",
                "Calories 200",
                "Portion 50 g"
            ])
        )
        XCTAssertFalse(
            NutritionFactsLabelGate.looksLikeNutritionFacts([
                "Grilled chicken breast with rice and broccoli"
            ])
        )
        XCTAssertFalse(
            NutritionFactsLabelGate.looksLikeNutritionFacts([
                "Calories 500",
                "Protein 40g"
            ])
        )
    }

    func testLabelScanResponseDecodesPerServingNutrition() throws {
        let json = """
        {
          "id": "LABEL_SCAN:012345678901",
          "name": "Protein bar",
          "brand": "ForgeLyte",
          "barcode": "012345678901",
          "serving": { "amount": 1, "unit": "1 bar (60 g)", "weight_g": 60 },
          "nutrition": {
            "calories": 190,
            "protein_g": 21,
            "carbs_g": 22,
            "fat_g": 7,
            "fiber_g": 3,
            "sugar_g": 1,
            "sodium_mg": 140
          },
          "source": {
            "type": "LABEL_SCAN_CONTRIBUTION",
            "external_id": "012345678901",
            "estimated": false
          }
        }
        """.data(using: .utf8)!
        let food = try JSONDecoder().decode(RemoteFood.self, from: json)
        XCTAssertEqual(food.sourceType, .labelScan)
        XCTAssertEqual(food.draft.sourceType, .labelScan)
        XCTAssertEqual(food.draft.calories, 190)
        XCTAssertFalse(food.draft.isEstimated)
        XCTAssertEqual(food.draft.barcode, "012345678901")
    }

    func testBarcodeLookupResponseDetectsLabelScanFallback() throws {
        let json = """
        { "status": "LABEL_SCAN_REQUIRED", "food": null }
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(BarcodeLookupResponse.self, from: json)
        XCTAssertTrue(result.needsLabelScan)
        XCTAssertNil(result.food)
    }

    func testScanBoxIgnoresBarcodesOutsideTheViewfinder() {
        let size = CGSize(width: 390, height: 720)
        let box = BarcodeScanBox.rect(in: size)
        XCTAssertGreaterThan(box.width, 100)
        XCTAssertTrue(box.minX > 0)
        XCTAssertTrue(BarcodeScanBox.contains(box.insetBy(dx: 12, dy: 8), in: size))
        XCTAssertFalse(
            BarcodeScanBox.contains(CGRect(x: 8, y: 8, width: 80, height: 24), in: size)
        )
    }

    func testSessionPayloadReadsForgeLyteUserKey() {
        let payload = Data(#"{"userKey":"fl_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLM","issuedAt":1,"expiresAt":2}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        let token = "\(payload).signature"
        XCTAssertEqual(
            ForgeLyteIdentityVault.userKey(fromSessionToken: token),
            "fl_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLM"
        )
    }

    func testDescribeResponseDecodesMatchesAndMissingFields() throws {
        let json = """
        {
          "estimated": true,
          "items": [
            {
              "name": "large egg",
              "brand": "",
              "quantity": 2,
              "unit": "egg",
              "estimated_weight_g": 100,
              "confidence": "high",
              "matches": [
                {
                  "id": "USDA:123",
                  "name": "Egg, whole, raw",
                  "brand": null,
                  "barcode": null,
                  "serving": { "amount": 1, "unit": "egg", "weight_g": 50 },
                  "nutrition": { "calories": 70, "protein_g": 6, "carbs_g": 0.4, "fat_g": 5 },
                  "source": { "type": "USDA", "external_id": "123", "estimated": false }
                }
              ]
            },
            {
              "name": "toast"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MealDescribeResponse.self, from: json)
        XCTAssertEqual(response.items.count, 2)
        XCTAssertTrue(response.isEstimated)
        XCTAssertEqual(response.items[0].estimatedWeightGrams, 100)
        XCTAssertEqual(response.items[0].matches.first?.sourceType, .usda)
        XCTAssertNil(response.items[0].brand)
        XCTAssertEqual(response.items[1].quantity, 1)
        XCTAssertEqual(response.items[1].unit, "serving")
        XCTAssertEqual(response.items[1].confidence, "low")
        XCTAssertTrue(response.items[1].matches.isEmpty)
    }

    func testDescribeScalesMatchNutritionByEstimatedWeight() throws {
        let match = try JSONDecoder().decode(RemoteFood.self, from: Data("""
        {
          "id": "USDA:123",
          "name": "Egg, whole, raw",
          "brand": null,
          "barcode": null,
          "serving": { "amount": 1, "unit": "egg", "weight_g": 50 },
          "nutrition": { "calories": 70, "protein_g": 6, "carbs_g": 0.4, "fat_g": 5, "fiber_g": 0, "sugar_g": 0.2, "sodium_mg": 70 },
          "source": { "type": "USDA", "external_id": "123", "estimated": false }
        }
        """.utf8))
        let item = DescribedMealItem(
            name: "large egg",
            quantity: 2,
            unit: "egg",
            estimatedWeightGrams: 100,
            confidence: "high",
            matches: [match]
        )
        let draft = MealDescribe.draft(item: item, match: match)

        XCTAssertEqual(MealDescribe.scaleFactor(item: item, serving: match.serving), 2)
        XCTAssertEqual(draft.calories, 140)
        XCTAssertEqual(draft.proteinGrams, 12)
        XCTAssertEqual(draft.sourceType, .aiEstimate)
        XCTAssertTrue(draft.isEstimated)
        XCTAssertEqual(draft.sourceFoodID, "123")
        XCTAssertEqual(draft.quantity, 2)
        XCTAssertEqual(MealDescribe.portionLabel(item), "2 egg · 100 g")
    }

    func testDescribeFallsBackToQuantityWhenWeightIsMissing() throws {
        let match = try JSONDecoder().decode(RemoteFood.self, from: Data("""
        {
          "id": "USDA:9",
          "name": "Toast",
          "brand": null,
          "barcode": null,
          "serving": { "amount": 1, "unit": "slice" },
          "nutrition": { "calories": 80, "protein_g": 3, "carbs_g": 14, "fat_g": 1 },
          "source": { "type": "USDA", "external_id": "9", "estimated": false }
        }
        """.utf8))
        let item = DescribedMealItem(
            name: "toast",
            quantity: 2,
            unit: "slice",
            estimatedWeightGrams: nil,
            confidence: "medium",
            matches: [match]
        )

        XCTAssertEqual(MealDescribe.scaleFactor(item: item, serving: match.serving), 2)
        XCTAssertEqual(MealDescribe.draft(item: item, match: match).calories, 160)
        XCTAssertTrue(ConfirmableDescribedFood(item: item).hasUsableNutrition)
    }

    func testDescribeScalesGramsFromPer100gNotAsServingCount() throws {
        let match = try JSONDecoder().decode(RemoteFood.self, from: Data("""
        {
          "id": "USDA:oatmeal",
          "name": "Instant oatmeal",
          "brand": "Brookshire",
          "barcode": null,
          "serving": { "amount": 1, "unit": "packet", "weight_g": 28 },
          "nutrition": { "calories": 357, "protein_g": 12, "carbs_g": 64, "fat_g": 7 },
          "nutrition_per_100g": { "calories": 370, "protein_g": 12, "carbs_g": 67, "fat_g": 7 },
          "source": { "type": "USDA", "external_id": "99", "estimated": false }
        }
        """.utf8))
        let item = DescribedMealItem(
            name: "instant oatmeal",
            brand: "Quaker",
            quantity: 60,
            unit: "g",
            estimatedWeightGrams: 60,
            confidence: "high",
            matches: [match]
        )
        let draft = MealDescribe.draft(item: item, match: match)

        XCTAssertEqual(MealDescribe.gramPortion(item), 60)
        XCTAssertEqual(MealDescribe.scaleFactor(item: item, match: match), 0.6)
        XCTAssertEqual(draft.calories, 222)
        XCTAssertNotEqual(draft.calories, 765)
        XCTAssertNotEqual(draft.calories, 357 * 60)
    }

    func testDescribeDoesNotTreatGramsAsServingsWhenWeightIsMissing() throws {
        let match = try JSONDecoder().decode(RemoteFood.self, from: Data("""
        {
          "id": "USDA:oats",
          "name": "Oats",
          "brand": null,
          "barcode": null,
          "serving": { "amount": 1, "unit": "serving" },
          "nutrition": { "calories": 370, "protein_g": 13, "carbs_g": 67, "fat_g": 7 },
          "source": { "type": "USDA", "external_id": "8", "estimated": false }
        }
        """.utf8))
        let item = DescribedMealItem(
            name: "instant oatmeal",
            quantity: 60,
            unit: "g",
            estimatedWeightGrams: 60,
            confidence: "medium",
            matches: [match]
        )

        XCTAssertEqual(MealDescribe.scaleFactor(item: item, serving: match.serving), 0.6)
        XCTAssertEqual(MealDescribe.draft(item: item, match: match).calories, 222)
    }

    func testDescribeDoesNotTreatRequiredEstimated100gAsThePortion() throws {
        let match = try JSONDecoder().decode(RemoteFood.self, from: Data("""
        {
          "id": "OPEN_FOOD_FACTS:oreo",
          "name": "OREO ORIGINAL",
          "brand": "Nabisco",
          "barcode": null,
          "serving": { "amount": 1, "unit": "11 g", "weight_g": 11 },
          "nutrition": { "calories": 52, "protein_g": 0.6, "carbs_g": 8, "fat_g": 2 },
          "nutrition_per_100g": { "calories": 472, "protein_g": 5.3, "carbs_g": 70, "fat_g": 20 },
          "source": { "type": "OPEN_FOOD_FACTS", "external_id": "oreo", "estimated": false }
        }
        """.utf8))
        let item = DescribedMealItem(
            name: "oreo",
            quantity: 1,
            unit: "cookie",
            estimatedWeightGrams: 100,
            confidence: "medium",
            matches: [match]
        )
        let draft = MealDescribe.draft(item: item, match: match)
        XCTAssertNil(MealDescribe.gramPortion(item))
        XCTAssertEqual(MealDescribe.scaleFactor(item: item, match: match), 1)
        XCTAssertEqual(draft.calories, 52)
        XCTAssertNotEqual(draft.calories, 472)
    }

    func testUnmatchedDescribeItemStaysEstimatedUntilEdited() {
        let item = DescribedMealItem(
            name: "mystery stew",
            quantity: 1,
            unit: "bowl",
            estimatedWeightGrams: 400,
            confidence: "low",
            matches: []
        )
        var food = ConfirmableDescribedFood(item: item)
        XCTAssertFalse(food.hasUsableNutrition)
        XCTAssertEqual(food.draft.sourceType, .aiEstimate)
        XCTAssertTrue(food.draft.isEstimated)
        XCTAssertEqual(food.draft.calories, 0)
        XCTAssertEqual(food.draft.name, "Mystery Stew")

        var edited = food.draft
        edited.calories = 520
        edited.proteinGrams = 28
        food.applyEditedDraft(edited)
        XCTAssertTrue(food.hasUsableNutrition)
        XCTAssertEqual(food.draft.calories, 520)
        XCTAssertTrue(food.draft.isEstimated)
        XCTAssertEqual(food.draft.sourceType, .aiEstimate)
    }

    func testFoodNamesTitleCaseWhenLowercase() {
        XCTAssertEqual(FoodNameFormatting.displayName("  chicken breast  "), "Chicken Breast")
        XCTAssertEqual(FoodNameFormatting.displayName("Chicken, broilers or fryers, breast"), "Chicken, broilers or fryers, breast")
        XCTAssertEqual(FoodNameFormatting.optionalDisplayName("quaker"), "Quaker")
        XCTAssertNil(FoodNameFormatting.optionalDisplayName("  "))
    }

    func testDescribeDraftPersistsUntilCleared() {
        let defaults = UserDefaults(suiteName: "AIDescribeDraftTests")!
        defaults.removePersistentDomain(forName: "AIDescribeDraftTests")

        XCTAssertEqual(AIDescribeDraft.load(from: defaults), "")
        AIDescribeDraft.save("2 eggs and toast", to: defaults)
        XCTAssertEqual(AIDescribeDraft.load(from: defaults), "2 eggs and toast")
        AIDescribeDraft.save("", to: defaults)
        XCTAssertEqual(AIDescribeDraft.load(from: defaults), "")
        AIDescribeDraft.save("chicken", to: defaults)
        AIDescribeDraft.clear(in: defaults)
        XCTAssertEqual(AIDescribeDraft.load(from: defaults), "")
    }

    func testCatalogueSearchCacheSkipsRepeatsInsideTTL() {
        var cache = CatalogueSearchCache(ttl: 60)
        let food = try! JSONDecoder().decode(RemoteFood.self, from: Data("""
        {
          "id": "USDA:1",
          "name": "Chicken breast",
          "brand": null,
          "barcode": null,
          "serving": { "amount": 1, "unit": "g", "weight_g": 100 },
          "nutrition": { "calories": 165, "protein_g": 31, "carbs_g": 0, "fat_g": 3.6 },
          "source": { "type": "USDA", "external_id": "1", "estimated": false }
        }
        """.utf8))
        XCTAssertNil(cache.foods(for: "Chicken Breast"))
        cache.store([food], for: "  chicken breast  ")
        XCTAssertEqual(cache.foods(for: "CHICKEN BREAST")?.first?.name, "Chicken breast")
        cache.store([], for: "empty")
        XCTAssertNil(cache.foods(for: "empty"))
    }
}
