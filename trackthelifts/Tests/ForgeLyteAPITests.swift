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
    }

    func testAPISourceMapping() {
        XCTAssertEqual(FoodSourceType.fromAPI("USDA"), .usda)
        XCTAssertEqual(FoodSourceType.fromAPI("OPEN_FOOD_FACTS"), .openFoodFacts)
        XCTAssertEqual(FoodSourceType.fromAPI("AI_ESTIMATE"), .aiEstimate)
        XCTAssertEqual(FoodSourceType.fromAPI("LABEL_SCAN_CONTRIBUTION"), .labelScan)
        XCTAssertEqual(FoodSourceType.fromAPI("USER_CONTRIBUTION"), .userContribution)
    }

    func testBarcodeNormalizationIgnoresFormattingAndLeadingZeros() {
        XCTAssertEqual(Barcode.normalize(" 0123-4567-8901 "), "012345678901")
        XCTAssertTrue(Barcode.matches("012345678901", "12345678901"))
        XCTAssertTrue(Barcode.matches("0000000000000", "0000000000000"))
        XCTAssertFalse(Barcode.matches("012345678901", "999"))
        XCTAssertEqual(FoodEntryDraft.manualBarcode("012345678901").sourceType, .manual)
        XCTAssertEqual(FoodEntryDraft.manualBarcode("012345678901").barcode, "012345678901")
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
}
