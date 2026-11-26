import SwiftUI

/// Menu 的 label 需要单独一个视图（Menu 里直接放带 hover 的 Button 不会响应）
/// 同样用 Label + .iconOnly，让 VoiceOver 能读到文字
struct HoverIconButtonLabel: View {
    let systemName: String
    var title: String = ""
    var size: CGFloat = 11
    var width: CGFloat = 24
    var height: CGFloat = 23

    @State private var hovering = false

    var body: some View {
        Label(title, systemImage: systemName)
            .labelStyle(.iconOnly)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(hovering ? Color.primary : Theme.textSecondary)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering ? Theme.hoverFill : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}
