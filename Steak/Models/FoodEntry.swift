import Foundation
import SwiftData

enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snacks"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "cookie.fill"
        }
    }

    static func suggested(for date: Date = Date()) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }
}

@Model
final class FoodEntry {
    @Attribute(.unique) var id: UUID
    var name: String
    var brand: String
    var barcode: String?
    /// Total kilocalories for the logged amount.
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var grams: Double
    var servingLabel: String
    var mealTypeRaw: String
    /// Start-of-day bucket the entry belongs to.
    var day: Date
    var createdAt: Date

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    init(
        name: String,
        brand: String = "",
        barcode: String? = nil,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        grams: Double,
        servingLabel: String = "",
        mealType: MealType,
        day: Date = Calendar.current.startOfDay(for: Date())
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.grams = grams
        self.servingLabel = servingLabel
        self.mealTypeRaw = mealType.rawValue
        self.day = day
        self.createdAt = Date()
    }
}
