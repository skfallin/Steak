import SwiftUI

enum Units {
    static func displayWeight(kg: Double, system: UnitsSystem) -> String {
        guard kg.isFinite else { return "—" }
        switch system {
        case .metric: return formatted(kg) + " kg"
        case .imperial: return formatted(kg * 2.20462) + " lb"
        }
    }

    static func displayHeight(cm: Double, system: UnitsSystem) -> String {
        guard cm.isFinite else { return "—" }
        switch system {
        case .metric: return formatted(cm) + " cm"
        case .imperial:
            let totalInches = cm / 2.54
            guard totalInches.isFinite else { return "—" }
            let feet = (totalInches / 12).rounded(.down)
            let inches = (totalInches - feet * 12).rounded()
            return "\(formatted(feet))′ \(formatted(inches))″"
        }
    }

    /// Weight value in kg from a user-entered display string.
    static func parseWeightToKg(_ text: String, system: UnitsSystem) -> Double? {
        guard let value = parse(text), value > 0 else { return nil }
        switch system {
        case .metric: return value
        case .imperial: return value / 2.20462
        }
    }

    /// Height value in cm from a user-entered display string.
    static func parseHeightToCm(_ text: String, system: UnitsSystem) -> Double? {
        guard let value = parse(text), value > 0 else { return nil }
        switch system {
        case .metric: return value
        case .imperial: return value * 2.54
        }
    }

    static func weightPlaceholder(system: UnitsSystem) -> String {
        system == .metric ? "70" : "155"
    }

    static func heightPlaceholder(system: UnitsSystem) -> String {
        system == .metric ? "175" : "510"
    }

    private static func parse(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)), value.isFinite else {
            return nil
        }
        return value
    }

    private static func formatted(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let fractionDigits = value.rounded() == value ? 0 : 1
        return value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }
}

extension Double {
    var kcalText: String {
        guard isFinite else { return "—" }
        return formatted(.number.precision(.fractionLength(0)))
    }

    var gramsText: String {
        guard isFinite else { return "—" }
        let fractionDigits = abs(self) >= 100 || rounded() == self ? 0 : 1
        return formatted(.number.precision(.fractionLength(fractionDigits)))
    }
}
