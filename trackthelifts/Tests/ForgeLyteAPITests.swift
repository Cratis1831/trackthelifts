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
