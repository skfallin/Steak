import SwiftUI

struct CalorieRing: View {
    let consumed: Double
    let goal: Double

    private var progress: Double {
        guard consumed.isFinite, goal.isFinite, goal > 0 else { return 0 }
        return min(max(consumed / goal, 0), 1)
    }

    private var remaining: Double {
        guard goal.isFinite, consumed.isFinite else { return 0 }
        return max((goal - consumed).rounded(), 0)
    }

    private var isOver: Bool { consumed.isFinite && goal.isFinite && consumed > goal }

    private var displayedAmount: Double {
        guard consumed.isFinite, goal.isFinite else { return 0 }
        return isOver ? max((consumed - goal).rounded(), 0) : remaining
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.1), lineWidth: 18)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: isOver
                            ? [Color.red.opacity(0.9), Color.red]
                            : [Color(red: 1.0, green: 0.42, blue: 0.21),
                               Color(red: 1.0, green: 0.68, blue: 0.25),
                               Color(red: 1.0, green: 0.42, blue: 0.21)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.6), value: progress)

            VStack(spacing: 2) {
                Text(isOver ? "over" : "left")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(displayedAmount.kcalText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .frame(width: 100)
                    .padding(.horizontal, 8)
                    .contentTransition(.numericText())
                    .animation(.smooth, value: remaining)

                Text("kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .circle)
    }
}

struct MacroBar: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color

    private var progress: Double {
        guard value.isFinite, target.isFinite, target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value.gramsText) / \(target.gramsText) g")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                Capsule()
                    .fill(.white.opacity(0.1))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * progress)
                            .animation(.smooth(duration: 0.5), value: progress)
                    }
            }
            .frame(height: 6)
        }
    }
}
