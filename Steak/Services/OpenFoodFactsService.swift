import Foundation

struct OFFProduct: Identifiable, Hashable, Sendable {
    let barcode: String
    let name: String
    let brand: String
    let kcalPer100g: Double?
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?
    let servingQuantityGrams: Double?
    let servingSizeLabel: String?

    var id: String { barcode.isEmpty ? name : barcode }
    var hasNutrition: Bool { kcalPer100g != nil }

    func scaled(grams: Double) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let factor = grams / 100
        return (
            calories: (kcalPer100g ?? 0) * factor,
            protein: (proteinPer100g ?? 0) * factor,
            carbs: (carbsPer100g ?? 0) * factor,
            fat: (fatPer100g ?? 0) * factor
        )
    }
}

enum OFFError: LocalizedError {
    case notFound
    case invalidBarcode
    case rateLimited(seconds: Int)
    case responseTooLarge
    case badResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Product not found in Open Food Facts."
        case .invalidBarcode:
            return "This barcode is not a valid product code."
        case .rateLimited(let seconds):
            return "Please wait \(seconds) second\(seconds == 1 ? "" : "s") before searching again."
        case .responseTooLarge:
            return "The Open Food Facts response was too large. Try a more specific search."
        case .badResponse:
            return "Unexpected response from Open Food Facts."
        case .network(let message):
            return message
        }
    }
}

/// Shared, in-process guard for the documented ten-searches-per-minute limit.
private actor OFFSearchRateLimiter {
    private var lastSearchStart: Date?

    func acquire() -> Int? {
        let now = Date()
        guard let lastSearchStart else {
            self.lastSearchStart = now
            return nil
        }

        let elapsed = now.timeIntervalSince(lastSearchStart)
        guard elapsed < 6 else {
            self.lastSearchStart = now
            return nil
        }
        return max(1, Int((6 - elapsed).rounded(.up)))
    }
}

enum BarcodeValidator {
    static let canonicalGTINLengths: Set<Int> = [8, 12, 13, 14]

    static func canonicalGTIN(_ barcode: String) -> String? {
        guard canonicalGTINLengths.contains(barcode.utf8.count),
              barcode.utf8.allSatisfy({ (48...57).contains($0) }),
              hasValidCheckDigit(barcode) else {
            return nil
        }
        return barcode
    }

    static func expandedUPCE(_ barcode: String) -> String? {
        guard barcode.utf8.count == 8,
              barcode.utf8.allSatisfy({ (48...57).contains($0) }) else {
            return nil
        }

        let digits = barcode.utf8.map { Character(UnicodeScalar($0)) }
        let numberSystem = digits[0]
        guard numberSystem == "0" || numberSystem == "1" else { return nil }

        let d1 = digits[1]
        let d2 = digits[2]
        let d3 = digits[3]
        let d4 = digits[4]
        let d5 = digits[5]
        let d6 = digits[6]
        let check = digits[7]
        let body: String
        switch d6 {
        case "0", "1", "2":
            body = "\(numberSystem)\(d1)\(d2)\(d6)0000\(d3)\(d4)\(d5)"
        case "3":
            body = "\(numberSystem)\(d1)\(d2)\(d3)00000\(d4)\(d5)"
        case "4":
            body = "\(numberSystem)\(d1)\(d2)\(d3)\(d4)00000\(d5)"
        default:
            body = "\(numberSystem)\(d1)\(d2)\(d3)\(d4)\(d5)0000\(d6)"
        }

        return canonicalGTIN(body + String(check))
    }

    static func hasValidCheckDigit(_ barcode: String) -> Bool {
        guard barcode.utf8.allSatisfy({ (48...57).contains($0) }) else { return false }
        let digits = barcode.utf8.map { Int($0 - 48) }
        guard digits.count > 1 else { return false }

        let sum = digits.dropLast().reversed().enumerated().reduce(0) { total, element in
            total + element.element * (element.offset.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - (sum % 10)) % 10 == digits.last
    }
}

enum NutritionSafety {
    static let maximumPortionGrams = 10_000.0
    static let maximumTotalCalories = 100_000.0
    static let maximumTotalMacros = 10_000.0

    static func isValidServingGrams(_ value: Double) -> Bool {
        value.isFinite && value > 0 && value <= maximumPortionGrams
    }

    static func isValidTotals(calories: Double, protein: Double, carbs: Double, fat: Double) -> Bool {
        calories.isFinite && protein.isFinite && carbs.isFinite && fat.isFinite
            && calories >= 0 && calories <= maximumTotalCalories
            && protein >= 0 && protein <= maximumTotalMacros
            && carbs >= 0 && carbs <= maximumTotalMacros
            && fat >= 0 && fat <= maximumTotalMacros
    }

    static func isAcceptableContentLength(_ expectedContentLength: Int64, limit: Int) -> Bool {
        expectedContentLength < 0 || expectedContentLength <= Int64(limit)
    }
}

struct OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private static let searchRateLimiter = OFFSearchRateLimiter()
    private static let productResponseLimit = 2 * 1024 * 1024
    private static let searchResponseLimit = 8 * 1024 * 1024

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "Steak/1.0 (https://github.com/skfallin/Steak)"]
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    /// Look up a single product by canonical GTIN via the v2 product API.
    func product(barcode: String) async throws -> OFFProduct {
        guard let barcode = BarcodeValidator.canonicalGTIN(barcode) else {
            throw OFFError.invalidBarcode
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v2/product/\(barcode).json"
        components.queryItems = [URLQueryItem(name: "fields", value: Self.productFields)]
        guard let url = components.url else { throw OFFError.network("Invalid URL") }

        let data = try await fetch(url, limit: Self.productResponseLimit)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OFFError.badResponse
        }
        guard json["status"] as? Int == 1, let product = json["product"] as? [String: Any],
              let parsed = Self.parse(product, barcode: barcode) else {
            throw OFFError.notFound
        }
        return parsed
    }

    /// Full-text search via the dedicated search service.
    func search(_ term: String) async throws -> [OFFProduct] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if let seconds = await Self.searchRateLimiter.acquire() {
            throw OFFError.rateLimited(seconds: seconds)
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "search.openfoodfacts.org"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "fields", value: Self.searchFields),
            URLQueryItem(name: "page_size", value: "25"),
        ]
        guard let url = components.url else { throw OFFError.network("Invalid URL") }

        let data = try await fetch(url, limit: Self.searchResponseLimit)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hits = json["hits"] as? [[String: Any]] else {
            throw OFFError.badResponse
        }
        return hits.compactMap { hit in
            let code = hit["code"] as? String ?? ""
            return Self.parse(hit, barcode: code)
        }
    }

    // MARK: - Internals

    private static let productFields = [
        "code",
        "product_name",
        "brands",
        "nutriments.energy-kcal_100g",
        "nutriments.energy-kj_100g",
        "nutriments.proteins_100g",
        "nutriments.carbohydrates_100g",
        "nutriments.fat_100g",
        "serving_quantity",
        "serving_quantity_unit",
        "serving_size",
    ].joined(separator: ",")

    // Search-a-licious only returns nutrition data when the top-level
    // `nutriments` field is requested. Parsing below still accepts only the
    // bounded per-100 g values used by Steak.
    private static let searchFields = [
        "code",
        "product_name",
        "brands",
        "nutriments",
        "serving_quantity",
        "serving_quantity_unit",
        "serving_size",
    ].joined(separator: ",")

    private func fetch(_ url: URL, limit: Int) async throws -> Data {
        do {
            let (bytes, response) = try await session.bytes(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw OFFError.network("Server error. Try again later.")
            }
            guard NutritionSafety.isAcceptableContentLength(response.expectedContentLength, limit: limit) else {
                throw OFFError.responseTooLarge
            }

            var data = Data()
            data.reserveCapacity(min(limit, max(0, Int(response.expectedContentLength))))
            for try await byte in bytes {
                guard data.count < limit else { throw OFFError.responseTooLarge }
                data.append(byte)
            }
            return data
        } catch let error as OFFError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch is URLError {
            throw OFFError.network("No connection. Check your network.")
        } catch {
            throw OFFError.network(error.localizedDescription)
        }
    }

    /// Tolerant parser for the product and search response shapes.
    static func parse(_ json: [String: Any], barcode: String) -> OFFProduct? {
        let code: String
        if barcode.isEmpty {
            code = ""
        } else if let normalized = BarcodeValidator.canonicalGTIN(barcode) {
            code = normalized
        } else {
            return nil
        }
        let name = boundedString(json["product_name"], limit: 160)
        guard !name.isEmpty else { return nil }

        let brand: String
        if let s = json["brands"] as? String {
            brand = boundedString(s, limit: 160)
        } else if let arr = json["brands"] as? [Any] {
            brand = boundedString(arr.compactMap { $0 as? String }.joined(separator: ", "), limit: 160)
        } else {
            brand = ""
        }

        let kcal = nutritionNumber(json, key: "energy-kcal_100g", maximum: 1_000)
            ?? nutritionNumber(json, key: "energy-kj_100g", maximum: 4_184).map { $0 / 4.184 }
        let protein = nutritionNumber(json, key: "proteins_100g", maximum: 100)
        let carbs = nutritionNumber(json, key: "carbohydrates_100g", maximum: 100)
        let fat = nutritionNumber(json, key: "fat_100g", maximum: 100)
        let servingUnit = boundedString(json["serving_quantity_unit"], limit: 24).lowercased()
        let serving = gramCompatibleServingQuantity(json["serving_quantity"], unit: servingUnit)

        return OFFProduct(
            barcode: code,
            name: name,
            brand: brand,
            kcalPer100g: kcal,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            servingQuantityGrams: serving,
            servingSizeLabel: boundedString(json["serving_size"], limit: 80)
        )
    }

    private static func nutritionNumber(_ json: [String: Any], key: String, maximum: Double) -> Double? {
        let nested = (json["nutriments"] as? [String: Any])?[key]
        let value = number(nested) ?? number(json["nutriments.\(key)"])
        guard let value, value.isFinite, value >= 0, value <= maximum else { return nil }
        return value
    }

    private static func gramCompatibleServingQuantity(_ value: Any?, unit: String) -> Double? {
        let gramUnits: Set<String> = ["g", "gram", "grams", "gramme", "grammes"]
        guard gramUnits.contains(unit), let quantity = number(value), NutritionSafety.isValidServingGrams(quantity) else {
            return nil
        }
        return quantity
    }

    private static func boundedString(_ value: Any?, limit: Int) -> String {
        let text = (value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(limit))
    }

    private static func number(_ value: Any?) -> Double? {
        let number: Double?
        switch value {
        case let n as NSNumber:
            number = n.doubleValue
        case let s as String:
            number = Double(s.replacingOccurrences(of: ",", with: "."))
        default:
            number = nil
        }
        guard let number, number.isFinite else { return nil }
        return number
    }
}
