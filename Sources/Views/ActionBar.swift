import SwiftUI

/// 现代图标功能条：占一卦、歇一下、两月视图、刷新、设置，带分色图标与悬停微弹动效。
struct ActionBar: View {
    var onDivination: () -> Void
    var onRest: () -> Void
    var onExpanded: () -> Void
    var onRefresh: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ActionBarItem(title: "占一卦", systemName: "sparkles", tint: Theme.accent, action: onDivination)
            ActionBarItem(title: "歇一下", systemName: "cup.and.saucer.fill", tint: Theme.jieqi, action: onRest)
            ActionBarItem(title: "两月", systemName: "calendar.day.timeline.left", tint: Theme.work, action: onExpanded)
            ActionBarItem(title: "刷新", systemName: "arrow.clockwise", tint: Theme.earnings, action: onRefresh)
            ActionBarItem(title: "设置", systemName: "gearshape.fill", tint: Theme.textSecondary, action: onSettings)
        }
    }
}

private struct ActionBarItem: View {
    let title: String
    let systemName: String
    let tint: Color
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(hovering ? tint : tint.opacity(0.88))
                    .symbolEffect(.bounce, value: hovering)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 10, weight: hovering ? .semibold : .medium))
                    .foregroundStyle(hovering ? Color.primary : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovering ? tint.opacity(0.10) : Theme.tileFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(hovering ? tint.opacity(0.28) : Theme.tileStroke, lineWidth: 0.6)
            }
            .scaleEffect(hovering ? 1.03 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: hovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointerCursor()
    }
}
