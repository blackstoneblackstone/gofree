import SwiftUI

/// 悬停高亮的小图标按钮（月份左右切换、放大、菜单等）
/// 视觉上只有图标，但用 Label + .iconOnly 保留文字给 VoiceOver
struct HoverIconButton: View {
    let systemName: String
    var size: CGFloat = 11
    var width: CGFloat = 26
    var height: CGFloat = 24
    var cornerRadius: CGFloat = 6
    var help: String = ""
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(help, systemImage: systemName)
                .labelStyle(.iconOnly)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(hovering ? Color.primary : Theme.textSecondary)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(hovering ? Theme.hoverFill : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
        .help(help)
    }
}
