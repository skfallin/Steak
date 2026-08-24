import SwiftUI

/// Reusable Liquid Glass styling helpers.

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 28) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

struct Theme {
    /// Warm steak-house gradient used for rings and accents.
    static let accentGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.42, blue: 0.21),
                 Color(red: 1.0, green: 0.68, blue: 0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let proteinColor = Color(red: 0.35, green: 0.78, blue: 0.72)
    static let carbsColor = Color(red: 0.55, green: 0.62, blue: 1.0)
    static let fatColor = Color(red: 1.0, green: 0.55, blue: 0.45)
}

extension Color {
    static let steakAccent = Color(red: 1.0, green: 0.52, blue: 0.23)
}
