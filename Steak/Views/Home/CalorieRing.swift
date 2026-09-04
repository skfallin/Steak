import SwiftUI

struct CalorieRing: View {
    let consumed: Double
    let goal: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var progress: Double {
        guard consumed.isFinite, goal.isFinite, goal > 0 else { return 0 }
        return min(max(consumed / goal, 0), 1)
    }

    private var isOver: Bool { consumed.isFinite && goal.isFinite && consumed > goal }

    private var displayedAmount: Double {
        guard consumed.isFinite, goal.isFinite else { return 0 }
        return abs((goal - consumed).rounded())
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    Text(displayedAmount.kcalText)
                        .font(.largeTitle.weight(.black))
                    Text(isOver ? "kcal over target" : "kcal left today")
                        .font(.title3.weight(.bold))
                    ProgressView(value: progress).tint(.white)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                calorieCut
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isOver ? "Calories over target" : "Calories remaining")
        .accessibilityValue("\(displayedAmount.kcalText) kilocalories")
    }

    private var calorieCut: some View {
        ZStack {
            SteakCut().fill(Theme.cutInk).offset(y: 6)
            SteakCut().fill(Theme.cutPaper)
            SteakCut().stroke(.white, lineWidth: 14)
            SteakCut()
                .trim(from: 0, to: progress)
                .stroke(Theme.cutInk, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: progress)

            VStack(spacing: 0) {
                Text(displayedAmount.kcalText)
                    .font(.system(size: 62, weight: .black, design: .rounded))
                    .tracking(-3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .contentTransition(.numericText())
                Text(isOver ? "kcal over target" : "kcal left today")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Theme.cutInk)
            .padding(.horizontal, 48)
        }
        .padding(10)
    }
}

struct MacroBar: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var progress: Double {
        guard value.isFinite, target.isFinite, target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) { labels }
                } else {
                    HStack { labels }
                }
            }
            .foregroundStyle(Theme.ink)

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.paper)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: geometry.size.width * progress)
                    }
                    .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.outline, lineWidth: 1.5) }
            }
            .frame(height: 13)
            .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: progress)
        }
        .accessibilityElement(children: .combine)
    }

    private var labels: some View {
        Group {
            Text(label).font(.subheadline.weight(.heavy))
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Text("\(value.gramsText) / \(target.gramsText) g")
                .font(.caption.weight(.semibold).monospacedDigit())
        }
    }
}
