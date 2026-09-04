import SwiftUI
import UIKit

enum Layout {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 20
    static let xxLarge: CGFloat = 24
    static let section: CGFloat = 32
    static let smallCornerRadius: CGFloat = 16
    static let mediumCornerRadius: CGFloat = 20
    static let largeCornerRadius: CGFloat = 28
    static let heroCornerRadius: CGFloat = 32
}

struct AtmosphericBackground: View {
    var body: some View {
        Theme.paper.ignoresSafeArea()
    }
}

struct Theme {
    static let paper = adaptive(
        light: UIColor(red: 1, green: 0.96, blue: 0.89, alpha: 1),
        dark: UIColor(red: 0.10, green: 0.055, blue: 0.065, alpha: 1)
    )
    static let surface = adaptive(
        light: .white,
        dark: UIColor(red: 0.17, green: 0.105, blue: 0.12, alpha: 1)
    )
    static let ink = adaptive(
        light: UIColor(red: 0.25, green: 0.055, blue: 0.075, alpha: 1),
        dark: UIColor(red: 1, green: 0.96, blue: 0.89, alpha: 1)
    )
    static let muted = adaptive(
        light: UIColor(red: 0.46, green: 0.29, blue: 0.28, alpha: 1),
        dark: UIColor(red: 0.81, green: 0.67, blue: 0.65, alpha: 1)
    )
    static let blush = adaptive(
        light: UIColor(red: 1, green: 0.83, blue: 0.80, alpha: 1),
        dark: UIColor(red: 0.28, green: 0.12, blue: 0.15, alpha: 1)
    )
    static let outline = adaptive(
        light: UIColor(red: 0.25, green: 0.055, blue: 0.075, alpha: 1),
        dark: UIColor(red: 0.58, green: 0.37, blue: 0.38, alpha: 1)
    )
    // Illustration colors stay fixed so the meat keeps its red-and-white identity.
    static let cutPaper = Color(red: 1, green: 0.96, blue: 0.89)
    static let cutInk = Color(red: 0.25, green: 0.055, blue: 0.075)
    static let shadow = adaptive(
        light: UIColor(red: 0.25, green: 0.055, blue: 0.075, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.015, blue: 0.02, alpha: 1)
    )
    static let accentGradient = Color.steakTint
    static let proteinColor = Color.steakTint
    static let carbsColor = ink
    static let fatColor = adaptive(
        light: UIColor(red: 0.66, green: 0.31, blue: 0.25, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.62, blue: 0.49, alpha: 1)
    )

    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension Color {
    static let steakAccent = Color(red: 0.80, green: 0.105, blue: 0.17)
    static let steakTint = Theme.adaptive(
        light: UIColor(red: 0.80, green: 0.105, blue: 0.17, alpha: 1),
        dark: UIColor(red: 1, green: 0.43, blue: 0.46, alpha: 1)
    )
}

extension View {
    func steakPanel(fill: Color = Theme.surface, radius: CGFloat = 24, raised: Bool = false) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Theme.outline, lineWidth: 2)
            }
            .background {
                if raised {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(Theme.shadow)
                        .offset(x: 0, y: 5)
                }
            }
    }

    func steakForm() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.paper)
            .fontDesign(.rounded)
            .tint(.steakTint)
    }
}

struct SteakButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .foregroundStyle(prominent ? Color.white : Theme.ink)
            .steakPanel(fill: prominent ? .steakAccent : Theme.surface, radius: 16, raised: !configuration.isPressed)
            .offset(y: configuration.isPressed ? 3 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// The asymmetric silhouette echoes the cut of meat in the app icon.
struct SteakCut: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0.15, y: 0.30))
        path.addCurve(to: CGPoint(x: 0.59, y: 0.07), control1: CGPoint(x: 0.25, y: 0.14), control2: CGPoint(x: 0.38, y: 0.09))
        path.addCurve(to: CGPoint(x: 0.92, y: 0.30), control1: CGPoint(x: 0.83, y: 0.01), control2: CGPoint(x: 0.95, y: 0.10))
        path.addCurve(to: CGPoint(x: 0.78, y: 0.79), control1: CGPoint(x: 0.87, y: 0.45), control2: CGPoint(x: 0.99, y: 0.59))
        path.addCurve(to: CGPoint(x: 0.25, y: 0.93), control1: CGPoint(x: 0.60, y: 0.98), control2: CGPoint(x: 0.36, y: 0.99))
        path.addCurve(to: CGPoint(x: 0.15, y: 0.30), control1: CGPoint(x: -0.03, y: 0.87), control2: CGPoint(x: 0.03, y: 0.48))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width, y: rect.height))
            .applying(CGAffineTransform(translationX: rect.minX, y: rect.minY))
    }
}

struct SteakIllustration: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SteakCut().fill(Theme.shadow).offset(y: 7)
                SteakCut().fill(Color.steakAccent)
                SteakCut().stroke(.white, lineWidth: 9)
                Path { path in
                    path.move(to: CGPoint(x: 0.13, y: 0.55))
                    path.addCurve(to: CGPoint(x: 0.85, y: 0.24), control1: CGPoint(x: 0.57, y: 0.17), control2: CGPoint(x: 0.53, y: 0.73))
                    path.move(to: CGPoint(x: 0.34, y: 0.38))
                    path.addQuadCurve(to: CGPoint(x: 0.32, y: 0.88), control: CGPoint(x: 0.63, y: 0.69))
                    path.move(to: CGPoint(x: 0.53, y: 0.59))
                    path.addQuadCurve(to: CGPoint(x: 0.83, y: 0.68), control: CGPoint(x: 0.65, y: 0.77))
                }
                .transform(CGAffineTransform(scaleX: geometry.size.width, y: geometry.size.height))
                .stroke(Theme.cutPaper, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        .aspectRatio(1.25, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
