import Foundation
import SwiftData

enum Sex: String, CaseIterable, Identifiable, Codable {
    case male, female
    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary, light, moderate, active, veryActive
    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .active: return "Very active"
        case .veryActive: return "Extremely active"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Desk job, little exercise"
        case .light: return "Exercise 1–3 days/week"
        case .moderate: return "Exercise 3–5 days/week"
        case .active: return "Exercise 6–7 days/week"
        case .veryActive: return "Physical job or daily training"
        }
    }
}

enum Goal: String, CaseIterable, Identifiable, Codable {
    case lose, maintain, gain
    var id: String { rawValue }

    var dailyDelta: Double {
        switch self {
        case .lose: return -500
        case .maintain: return 0
        case .gain: return +300
        }
    }

    var label: String {
        switch self {
        case .lose: return "Lose weight"
        case .maintain: return "Maintain"
        case .gain: return "Gain muscle"
        }
    }
}

enum UnitsSystem: String, CaseIterable, Identifiable, Codable {
    case metric, imperial
    var id: String { rawValue }

    var label: String {
        switch self {
        case .metric: return "Metric (kg · cm)"
        case .imperial: return "Imperial (lb · ft)"
        }
    }
}

@Model
final class UserProfile {
    var name: String = ""
    var sexRaw: String = Sex.male.rawValue
    var age: Int = 25
    var heightCm: Double = 175
    var weightKg: Double = 70
    var activityRaw: String = ActivityLevel.moderate.rawValue
    var goalRaw: String = Goal.maintain.rawValue
    var unitsRaw: String = UnitsSystem.metric.rawValue
    var manualCalorieGoal: Int?
    var hasCompletedOnboarding: Bool = false
    var createdAt: Date = Date()

    init() {}

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }
    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }
    var goal: Goal {
        get { Goal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }
    var units: UnitsSystem {
        get { UnitsSystem(rawValue: unitsRaw) ?? .metric }
        set { unitsRaw = newValue.rawValue }
    }

    var dailyCalorieGoal: Int { manualCalorieGoal ?? CalorieCalculator.dailyTarget(for: self) }
}
