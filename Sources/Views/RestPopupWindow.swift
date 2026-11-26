import AppKit
import SwiftUI

/// 定时休息提醒浮窗：右上角非抢焦点卡片，支持直接开始 2–3 分钟休息倒计时、换一个或 10 分钟后再提醒
@MainActor
enum RestPopupWindow {

    private static var panel: NSPanel?
    private static let width: CGFloat = 352

    static var isVisible: Bool {
        panel?.isVisible == true
    }

    static func isPopupWindow(_ candidate: NSWindow) -> Bool {
        panel === candidate
    }

    static func show(manager: RestReminderManager) {
        if let panel {
            reposition(panel)
            panel.orderFrontRegardless()
            return
        }

        let root = RestPopupView(manager: manager, onResize: {
            if let current = Self.panel {
                resizeAndReposition(current)
            }
        })
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 240)
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let size = NSSize(width: width, height: max(180, fitting.height))
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting

        self.panel = panel
        reposition(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    static func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        })
    }

    private static func resizeAndReposition(_ panel: NSPanel) {
        guard let hosting = panel.contentView else { return }
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let targetHeight = max(180, fitting.height)
        guard abs(panel.frame.height - targetHeight) > 1 else { return }
        var frame = panel.frame
        let topY = frame.maxY
        frame.size = NSSize(width: width, height: targetHeight)
        frame.origin.y = topY - targetHeight
        panel.setFrame(frame, display: true, animate: true)
    }

    private static func reposition(_ panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let margin: CGFloat = 16
        let origin = NSPoint(
            x: visible.maxX - panel.frame.width - margin,
            y: visible.maxY - panel.frame.height - margin
        )
        panel.setFrameOrigin(origin)
    }
}

/// 提醒浮窗内容视图
struct RestPopupView: View {
    @Bindable var manager: RestReminderManager
    var onResize: () -> Void = {}

    private var activity: RestActivity {
        manager.activeSession?.activity ?? manager.currentActivity
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header

            // 3D 动作演示舞台：一眼看懂现在要做什么
            Rest3DSceneView(activity: activity, height: 176)

            if let session = manager.activeSession {
                activeSessionBody(session)
            } else {
                suggestionBody
            }
        }
        .padding(16)
        .frame(width: 352, alignment: .leading)
        .background {
            ZStack {
                VisualEffectBackground(material: .popover)
                Theme.surface
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.cardSolidStroke, lineWidth: 0.8)
        }
        .onChange(of: manager.currentActivity.id) { _, _ in
            DispatchQueue.main.async { onResize() }
        }
        .onChange(of: manager.activeSession?.isCompleted) { _, _ in
            DispatchQueue.main.async { onResize() }
        }
        .onChange(of: manager.activeSession == nil) { _, _ in
            DispatchQueue.main.async { onResize() }
        }
    }

    // MARK: - 顶部标签栏

    private var header: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: activity.category.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(activity.category.shortBadge)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(activity.category.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background {
                Capsule(style: .continuous)
                    .fill(activity.category.tint.opacity(0.13))
            }

            if let badge = activity.badge {
                Text(badge)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.earnings)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        Capsule(style: .continuous)
                            .fill(Theme.earnings.opacity(0.14))
                    }
            }

            Spacer(minLength: 4)

            Button {
                RestWindow.open()
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .help("查看全部休息指南")

            Button {
                manager.dismissReminder()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.innerFill))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .help("关闭提醒")
        }
    }

    // MARK: - 建议态

    private var suggestionBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: activity.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(activity.category.tint)
                    .frame(width: 30, height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(activity.category.tint.opacity(0.12))
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(activity.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("建议时长约 \(activity.durationLabel) · 起来松一口气")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(activity.steps) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(step.id)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(activity.category.tint)
                            .frame(width: 18, height: 18)
                            .background {
                                Circle()
                                    .fill(activity.category.tint.opacity(0.14))
                            }
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(step.title)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Spacer(minLength: 4)
                                Text(step.durationLabel)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(Theme.textTertiary)
                                    .monospacedDigit()
                            }
                            Text(step.instruction)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.textSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.tileFill)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.tileStroke, lineWidth: 0.5)
                    }
                }
            }

            if manager.isAfternoon && activity.id != RestActivity.afternoonEmergency.id {
                afternoonCallout
            }

            HStack(spacing: 6) {
                Button {
                    manager.startBreak(activity)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9.5))
                        Text("开始休息 \(activity.durationLabel)")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(activity.category.tint)
                    }
                }
                .buttonStyle(.plain)
                .pointerCursor()

                secondaryButton(title: "换一个", icon: "arrow.triangle.2.circlepath") {
                    manager.shuffleActivity()
                }

                secondaryButton(title: "10分后", icon: "clock") {
                    manager.snooze(minutes: 10)
                }
            }
            .padding(.top, 2)
        }
    }

    private var afternoonCallout: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.earnings)
            Text("下午犯困扛不住？试试「不带手机闭眼 2 分钟 + 冷水冲手腕」")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("急救") {
                manager.startBreak(RestActivity.afternoonEmergency)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Theme.earnings)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(Theme.earnings.opacity(0.14))
            }
            .pointerCursor()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.earnings.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.earnings.opacity(0.20), lineWidth: 0.5)
        }
    }

    // MARK: - 倒计时态

    private func activeSessionBody(_ session: ActiveRestSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Theme.innerFill, lineWidth: 3.5)
                    Circle()
                        .trim(from: 0, to: session.progress)
                        .stroke(
                            session.isCompleted ? Theme.jieqi : activity.category.tint,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.35), value: session.progress)

                    if session.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.jieqi)
                    } else {
                        Text(session.formattedRemaining)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                            .contentTransition(.numericText())
                    }
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.isCompleted ? "休息完成，状态回血" : session.activity.title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Text(
                        session.isCompleted
                            ? "今日已休息 \(manager.completedTodayCount) 次，窗口即将自动收起"
                            : "正在进行第 \(session.currentStepIndex + 1)/\(session.activity.steps.count) 步 · 本步剩 \(session.currentStepRemainingSeconds) 秒"
                    )
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !session.isCompleted {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(session.activity.steps.enumerated()), id: \.element.id) { idx, step in
                        let isDone = idx < session.currentStepIndex
                        let isCurrent = idx == session.currentStepIndex

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            isDone
                                                ? Theme.jieqi.opacity(0.18)
                                                : (isCurrent ? activity.category.tint : Theme.innerFill)
                                        )
                                    if isDone {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Theme.jieqi)
                                    } else {
                                        Text("\(step.id)")
                                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                            .foregroundStyle(isCurrent ? Color.white : Theme.textTertiary)
                                    }
                                }
                                .frame(width: 18, height: 18)
                                .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(step.title)
                                            .font(.system(size: 11.5, weight: isCurrent ? .bold : .medium))
                                            .foregroundStyle(isDone ? Theme.textTertiary : Color.primary)
                                            .strikethrough(isDone, color: Theme.textTertiary)
                                        Spacer(minLength: 4)
                                        Text(isCurrent ? "还剩 \(session.currentStepRemainingSeconds)s" : step.durationLabel)
                                            .font(.system(size: 9.5, weight: isCurrent ? .semibold : .regular))
                                            .foregroundStyle(isCurrent ? activity.category.tint : Theme.textTertiary)
                                            .monospacedDigit()
                                    }

                                    if isCurrent {
                                        Text(step.instruction)
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineSpacing(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }

                            if isCurrent {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule(style: .continuous)
                                            .fill(activity.category.tint.opacity(0.15))
                                        Capsule(style: .continuous)
                                            .fill(activity.category.tint)
                                            .frame(width: max(4, geo.size.width * session.currentStepProgress))
                                            .animation(.linear(duration: 0.35), value: session.currentStepProgress)
                                    }
                                }
                                .frame(height: 3)
                                .padding(.leading, 26)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, isCurrent ? 7 : 5)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isCurrent ? activity.category.tint.opacity(0.10) : Theme.tileFill.opacity(0.65))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isCurrent ? activity.category.tint.opacity(0.32) : Theme.tileStroke,
                                    lineWidth: isCurrent ? 0.9 : 0.5
                                )
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if session.isCompleted {
                    Button {
                        manager.dismissReminder()
                    } label: {
                        Text("回到工作")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.jieqi)
                            }
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                } else {
                    Button {
                        manager.finishBreak(autoDismissPopup: false)
                        RestPopupWindow.hide()
                    } label: {
                        Text("提前完成")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(activity.category.tint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(activity.category.tint.opacity(0.13))
                            }
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()

                    secondaryButton(title: "取消", icon: nil) {
                        manager.cancelBreak()
                        RestPopupWindow.hide()
                    }
                }
            }
        }
    }

    private func secondaryButton(title: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.tileFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.tileStroke, lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}
