import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case light, dark, system

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}
