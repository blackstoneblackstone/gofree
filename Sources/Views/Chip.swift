import SwiftUI

struct Chip: View {
    let text: String
    let color: Color
    var help: String = ""

    @Environment(\.colorScheme) private var scheme

    private var isDark: Bool { scheme == .dark }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6.5)
            .padding(.vertical, 2.8)
            .background(Capsule(style: .continuous).fill(color.opacity(isDark ? 0.16 : 0.12)))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(color.opacity(isDark ? 0.3 : 0.16), lineWidth: 0.5)
            )
            .help(help)
    }
}
