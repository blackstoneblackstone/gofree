import SwiftUI

/// 六爻图：自上而下画上爻到初爻，上下卦之间留 8pt 分界，动爻用朱砂红加 ○／× 记号。
struct YaoStack: View {
    let lines: [CoinLine]
    let titles: [String]

    private static let barWidth: CGFloat = 64
    private static let barHeight: CGFloat = 6
    private static let gap: CGFloat = 6
    private static let trigramGap: CGFloat = 6
    private static let labelWidth: CGFloat = 32
    private static let markWidth: CGFloat = 14

    var body: some View {
        VStack(spacing: Self.gap) {
            ForEach(Array(lines.enumerated()).reversed(), id: \.offset) { index, line in
                row(line: line, title: title(at: index))
                    .padding(.bottom, index == 3 ? Self.trigramGap : 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
    }

    private func title(at index: Int) -> String {
        titles.indices.contains(index) ? titles[index] : ""
    }

    private func row(line: CoinLine, title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: line.isChanging ? .medium : .regular))
                .foregroundStyle(line.isChanging ? Theme.divineAccent : Theme.divineInkTertiary)
                .frame(width: Self.labelWidth, alignment: .trailing)
            bars(isYang: line.isYang, color: line.isChanging ? Theme.divineAccent : Theme.divineInk.opacity(0.78))
            Text(line.mark ?? " ")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.divineAccent)
                .frame(width: Self.markWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private func bars(isYang: Bool, color: Color) -> some View {
        if isYang {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: Self.barWidth, height: Self.barHeight)
                .frame(width: Self.barWidth, alignment: .center)
        } else {
            HStack(spacing: 8) {
                segment(color)
                segment(color)
            }
            .frame(width: Self.barWidth)
        }
    }

    private func segment(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: (Self.barWidth - 8) / 2, height: Self.barHeight)
    }

    private var accessibilityText: String {
        lines.enumerated().map { index, line in
            "\(title(at: index)) \(line.label)\(line.isChanging ? "，动" : "")"
        }.joined(separator: "；")
    }
}