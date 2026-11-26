import SwiftUI

/// 五星制重要级别：实心星表示级别（统一金色，避免和周末/节日的红撞色）
struct StarRating: View {
    let level: Int

    var body: some View {
        let filled = max(0, min(5, level))
        let color = Theme.earnings
        HStack(spacing: 0.8) {
            ForEach(0..<5, id: \.self) { index in
                Text("★")
                    .font(.system(size: 7))
                    .foregroundStyle(index < filled ? color : Color.primary.opacity(0.13))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "重要级别 \(filled) 星，共 5 星"))
    }
}
