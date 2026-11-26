import SwiftUI

/// 定时休息状态一行（放进主弹窗，视觉与 WeatherLine 对齐）
struct RestLine: View {
    @Bindable var manager: RestReminderManager
    var onOpen: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.primary)
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())

            if let sub = subText {
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if manager.activeSession == nil {
                Button {
                    manager.togglePause()
                } label: {
                    Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 22, height: 20)
                        .background {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Theme.innerFill)
                        }
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .help(manager.isPaused ? "继续休息计时" : "暂停休息计时")

                Button {
                    manager.triggerNow()
                } label: {
                    Text("歇一下")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.jieqi)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Theme.jieqi.opacity(0.13))
                        }
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .help("立即弹出休息提醒")
            } else {
                Button {
                    RestPopupWindow.show(manager: manager)
                } label: {
                    Text("查看")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Theme.accent.opacity(0.13))
                        }
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovering ? Theme.hoverFill : Theme.tileFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.tileStroke, lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            onOpen()
        }
        .onHover { hovering = $0 }
        .pointerCursor()
    }

    private var iconName: String {
        if let session = manager.activeSession {
            return session.isCompleted ? "checkmark.circle.fill" : session.activity.icon
        }
        if manager.isSuppressedByCasting { return "airplayvideo" }
        if manager.isPaused { return "pause.circle.fill" }
        return "cup.and.saucer.fill"
    }

    private var iconTint: Color {
        if let session = manager.activeSession {
            return session.isCompleted ? Theme.jieqi : session.activity.category.tint
        }
        if manager.isSuppressedByCasting || manager.isPaused || manager.isOutsideWorkHours { return Theme.earnings }
        return Theme.jieqi
    }

    private var statusText: String {
        if let session = manager.activeSession {
            return session.isCompleted
                ? "休息完成"
                : "休息中 \(session.formattedRemaining)"
        }
        if manager.isSuppressedByCasting {
            return "\(manager.castingReason ?? "投屏中") · 已静默"
        }
        if manager.isPaused {
            return "休息提醒已暂停"
        }
        if manager.isOutsideWorkHours {
            return "非工作时段静默"
        }
        return "下次休息 \(manager.compactCountdownLabel)"
    }

    private var subText: String? {
        if let session = manager.activeSession {
            return session.activity.title
        }
        if manager.completedTodayCount > 0 {
            return "今日 \(manager.completedTodayCount) 次"
        }
        return nil
    }
}
