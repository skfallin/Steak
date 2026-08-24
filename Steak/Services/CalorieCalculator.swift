import Foundation

enum CalorieCalculator {
    /// Mifflin-St Jeor basal metabolic rate.
    static func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    static func tdee(profile: UserProfile) -> Double {
        bmr(sex: profile.sex, weightKg: profile.weightKg, heightCm: profile.heightCm, age: profile.age)
            * profile.activity.multiplier
    }

    static func dailyTarget(for profile: UserProfile) -> Int {
        let target = tdee(profile: profile) + profile.goal.dailyDelta
        let floor: Double = profile.sex == .male ? 1500 : 1200
        guard target.isFinite else { return Int(floor) }
        // Profile inputs are normally constrained by onboarding. This protects
        // existing malformed stores from an out-of-range Double-to-Int conversion.
        let bounded = min(max(target.rounded(), floor), 1_000_000)
        return Int(bounded)
    }

    /// Macro split: 30% protein / 40% carbs / 30% fat.
    static func macroTargets(totalCalories: Int) -> (protein: Double, carbs: Double, fat: Double) {
        let cal = Double(totalCalories)
        return (
            protein: cal * 0.30 / 4,
            carbs: cal * 0.40 / 4,
            fat: cal * 0.30 / 9
        )
    }
}
