//
//  ForgeLyteAPI.swift
//  TrackTheLifts
//

import Foundation

enum ForgeLyteAPI {
    static let productionHost = "https://forgelyte-server.vercel.app"
    static let debugOverrideKey = "forgelyteAPIBaseURL"
    static let localDefaultHost = "http://127.0.0.1:3000"

    static var baseURL: URL {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: debugOverrideKey),
           let url = URL(string: override),
           !override.isEmpty {
            return url
        }
        return URL(string: localDefaultHost)!
        #else
        return URL(string: productionHost)!
        #endif
    }

    static func searchFoods(_ query: String) async throws -> [RemoteFood] {
        var components = URLComponents(
            url: baseURL.appending(path: "api/foods/search"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else {
            throw ForgeLyteAPIError.invalidRequest
        }

        let payload: SearchResponse = try await request(url)
        return payload.foods
    }

    static func lookupBarcode(_ barcode: String) async throws -> BarcodeLookupResponse {
        let encoded = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        let url = baseURL.appending(path: "api/foods/barcode/\(encoded)")
        return try await request(url)
    }

    static func bootstrap(signedAppTransaction: String) async throws -> BootstrapResponse {
        let url = baseURL.appending(path: "api/bootstrap")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            BootstrapRequest(signedAppTransaction: signedAppTransaction)
        )
        return try await send(request)
    }

    private static func request<T: Decodable>(_ url: URL) async throws -> T {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        return try await send(urlRequest)
    }

    private static func send<T: Decodable>(_ urlRequest: URLRequest) async throws -> T {
        var request = urlRequest
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let token = ForgeLyteIdentityVault.sessionToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ForgeLyteAPIError.unreachable(baseURL)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ForgeLyteAPIError.invalidServerResponse
        }

        if http.statusCode == 401 {
            throw ForgeLyteAPIError.sessionExpired
        }
        if http.statusCode == 403 {
            throw ForgeLyteAPIError.proRequired
        }
        if (500...599).contains(http.statusCode) {
            throw ForgeLyteAPIError.unavailable
        }
        if !(200...299).contains(http.statusCode) {
            if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw ForgeLyteAPIError.server(envelope.error.message)
            }
            throw ForgeLyteAPIError.invalidServerResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

struct BootstrapRequest: Encodable {
    let signedAppTransaction: String
}

struct BootstrapResponse: Decodable {
    let userKey: String
    let sessionToken: String
    let expiresAt: Double?
    let isPro: Bool?
}

struct SearchResponse: Decodable {
    let foods: [RemoteFood]
}

struct BarcodeLookupResponse: Decodable {
    let status: String
    let food: RemoteFood?

    var needsLabelScan: Bool { status == "LABEL_SCAN_REQUIRED" }
}

struct RemoteFood: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let barcode: String?
    let serving: Serving
    let nutrition: Nutrition
    let source: Source

    struct Serving: Decodable, Hashable {
        let amount: Double?
        let unit: String?
        let weightGrams: Double?

        enum CodingKeys: String, CodingKey {
            case amount
            case unit
            case weightGrams = "weight_g"
        }
    }

    struct Nutrition: Decodable, Hashable {
        let calories: Double?
        let proteinGrams: Double?
        let carbsGrams: Double?
        let fatGrams: Double?
        let fiberGrams: Double?
        let sugarGrams: Double?
        let sodiumMilligrams: Double?

        enum CodingKeys: String, CodingKey {
            case calories
            case proteinGrams = "protein_g"
            case carbsGrams = "carbs_g"
            case fatGrams = "fat_g"
            case fiberGrams = "fiber_g"
            case sugarGrams = "sugar_g"
            case sodiumMilligrams = "sodium_mg"
        }
    }

    struct Source: Decodable, Hashable {
        let type: String
        let externalID: String?
        let estimated: Bool?

        enum CodingKeys: String, CodingKey {
            case type
            case externalID = "external_id"
            case estimated
        }
    }

    var sourceType: FoodSourceType {
        FoodSourceType.fromAPI(source.type)
    }

    var draft: FoodEntryDraft {
        FoodEntryDraft(
            id: id,
            name: name,
            brand: brand,
            calories: nutrition.calories ?? 0,
            proteinGrams: nutrition.proteinGrams ?? 0,
            carbsGrams: nutrition.carbsGrams ?? 0,
            fatGrams: nutrition.fatGrams ?? 0,
            fiberGrams: nutrition.fiberGrams,
            sugarGrams: nutrition.sugarGrams,
            sodiumMilligrams: nutrition.sodiumMilligrams,
            servingDescription: serving.unit.map { $0 == "g" ? "\(Int(serving.weightGrams ?? 100)) g" : $0 },
            servingWeightGrams: serving.weightGrams,
            barcode: barcode,
            sourceType: sourceType,
            sourceFoodID: source.externalID ?? id,
            isEstimated: source.estimated ?? sourceType.isEstimated
        )
    }
}

struct FoodEntryDraft: Identifiable, Hashable {
    let id: String
    var name: String
    var brand: String?
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double?
    var sugarGrams: Double?
    var sodiumMilligrams: Double?
    var servingDescription: String?
    var servingWeightGrams: Double?
    var barcode: String?
    var sourceType: FoodSourceType
    var sourceFoodID: String?
    var isEstimated: Bool
}

extension CustomFood {
    var draft: FoodEntryDraft {
        FoodEntryDraft(
            id: id.uuidString,
            name: name,
            brand: brand,
            calories: calories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            sugarGrams: sugarGrams,
            sodiumMilligrams: sodiumMilligrams,
            servingDescription: servingDescription,
            servingWeightGrams: servingWeightGrams,
            barcode: barcode,
            sourceType: .custom,
            sourceFoodID: id.uuidString,
            isEstimated: false
        )
    }
}

extension FoodSourceType {
    static func fromAPI(_ raw: String) -> FoodSourceType {
        switch raw {
        case "USDA": return .usda
        case "OPEN_FOOD_FACTS": return .openFoodFacts
        case "USER_CONTRIBUTION": return .userContribution
        case "LABEL_SCAN_CONTRIBUTION": return .labelScan
        case "AI_ESTIMATE": return .aiEstimate
        case "FORGELYTE_CURATED": return .custom
        default: return .custom
        }
    }
}

private struct APIErrorEnvelope: Decodable {
    struct Details: Decodable {
        let code: String
        let message: String
    }

    let error: Details
}

enum ForgeLyteAPIError: LocalizedError {
    case invalidRequest
    case invalidServerResponse
    case sessionExpired
    case proRequired
    case unavailable
    case missingAppTransaction
    case unreachable(URL)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "The food search request was invalid."
        case .invalidServerResponse:
            return "ForgeLyte could not read the food catalogue response."
        case .sessionExpired:
            return "Open ForgeLyte Lift again, then retry."
        case .proRequired:
            return "ForgeLyte Pro is required to search the food catalogue."
        case .unavailable:
            return "The food catalogue is unavailable right now."
        case .missingAppTransaction:
            return "The App Store could not verify this install yet."
        case .unreachable(let url):
            return "Can't reach the food API at \(url.absoluteString). On a physical iPhone, set Settings → Local API Host to your Mac's IP, like http://10.0.0.169:3000."
        case .server(let message):
            return message
        }
    }
}
