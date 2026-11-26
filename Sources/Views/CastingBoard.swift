import SwiftUI

/// 起卦过程：自下而上逐爻落成，当前这一爻显示演算中的样子。
struct CastingBoard: View {
    let method: DivinationMethod
    let values: [Int]
    let revealed: Int
    let rollingIndex: Int?
    let coinFaces: [Bool]
    let yarrowCounts: [Int]

    private static let barWidth: CGFloat = 64
    private static let barHeight: CGFloat = 6
    private static let gap: CGFloat = 6
    private static let trigramGap: CGFloat = 6
    private static let labelWidth: CGFloat = 32
    private static let markWidth: CGFloat = 14

    var body: some View {
        VStack(spacing: Self.gap) {
            ForEach(Array((0..<6).reversed()), id: \.self) { index in
                row(index: index)
                    .padding(.bottom, index == 3 ? Self.trigramGap : 0)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: revealed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
    }

    private func row(index: Int) -> some View {
        let isRevealed = index < revealed
        let isRolling = index == rollingIndex
        let changing = isRevealed && Self.isChanging(values[safe: index])
        let color = changing ? Theme.divineAccent : Theme.divineInk.opacity(0.78)

        return HStack(spacing: 8) {
            Text(DivinationResult.positionName(index + 1))
                .font(.system(size: 11, weight: isRolling ? .medium : .regular))
                .foregroundStyle(isRolling ? Theme.divineInk : Theme.divineInkTertiary)
                .frame(width: Self.labelWidth, alignment: .trailing)

            Group {
                if isRevealed {
                    bar(isYang: Self.isYang(values[safe: index]), color: color)
                } else if isRolling {
                    rollingContent
                } else {
                    bar(isYang: true, color: Theme.divineInk.opacity(0.08))
                }
            }
            .frame(width: Self.barWidth, height: 16)

            Text(isRevealed && changing ? (Self.isYang(values[safe: index]) ? "○" : "×") : " ")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.divineAccent)
                .frame(width: Self.markWidth, alignment: .leading)
        }
        .frame(height: 16)
    }

    @ViewBuilder
    private var rollingContent: some View {
        switch method {
        case .coins:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    coin(back: coinFaces[safe: index] ?? false)
                }
            }
        case .takashima, .yarrow:
            Capsule()
                .fill(Theme.divineAccent.opacity(0.6))
                .frame(width: Self.barWidth, height: Self.barHeight)
                .opacity(yarrowCounts.isEmpty ? 0.35 : 0.92)
                .scaleEffect(x: 0.72 + 0.28 * CGFloat(min(yarrowCounts.count, 3)) / 3)
        }
    }

    private func coin(back: Bool) -> some View {
        Text(back ? "背" : "字")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(back ? Theme.divineAccent : Theme.divineInkTertiary)
            .frame(width: 16, height: 16)
            .background {
                Circle().fill(Theme.divineAccent.opacity(back ? 0.16 : 0.06))
            }
            .overlay {
                Circle().strokeBorder(Theme.divineAccent.opacity(back ? 0.4 : 0.15), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    private func bar(isYang: Bool, color: Color) -> some View {
        if isYang {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: Self.barWidth, height: Self.barHeight)
        } else {
            HStack(spacing: 8) {
                segment(color)
                segment(color)
            }
        }
    }

    private func segment(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: (Self.barWidth - 8) / 2, height: Self.barHeight)
    }

    private var accessibilityText: String {
        let done = (0..<min(revealed, 6)).map { index in
            "\(DivinationResult.positionName(index + 1)) \(Self.isYang(values[safe: index]) ? "阳" : "阴")"
        }
        return done.isEmpty ? "尚未成爻" : "已成 " + done.joined(separator: "、")
    }

    private static func isYang(_ value: Int?) -> Bool {
        guard let value else { return true }
        return value == 7 || value == 9
    }

    private static func isChanging(_ value: Int?) -> Bool {
        guard let value else { return false }
        return value == 6 || value == 9
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}