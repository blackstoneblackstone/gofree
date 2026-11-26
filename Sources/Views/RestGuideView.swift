import SwiftUI

struct RestGuideView: View {
    @Bindable var manager: RestReminderManager
    @Bindable var settings: AppSettings
    @State private var previewActivity: RestActivity = RestReminderManager.shared.currentActivity

    private let intervalOptions = [20, 30, 45, 60, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusCard

                previewStageCard

                if let session = manager.activeSession {
                    activeBreakBanner(session)
                }

                emergencyCard

                ForEach(RestCategory.allCases) { category in
                    categorySection(category)
                }
            }
            .padding(16)
        }
        .background(Theme.divineSurface)
        .onChange(of: manager.currentActivity.id) { _, _ in
            previewActivity = manager.currentActivity
        }
    }

    // MARK: - 3D 动作演示预览卡

    private var previewStageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("3D 动作演示")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text("· \(previewActivity.title)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("可拖拽旋转 · 点下方切换")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            Rest3DSceneView(activity: previewActivity, height: 188)

            // 选中项目的分步执行清单
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("休息步骤")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 4)
                    Button {
                        manager.startBreak(previewActivity)
                        RestPopupWindow.show(manager: manager)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8.5))
                            Text("按步骤休息 · \(previewActivity.durationLabel)")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background {
                            Capsule(style: .continuous)
                                .fill(previewActivity.category.tint)
                        }
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }

                ForEach(previewActivity.steps) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(step.id)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(previewActivity.category.tint)
                            .frame(width: 18, height: 18)
                            .background {
                                Circle()
                                    .fill(previewActivity.category.tint.opacity(0.14))
                            }
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 1.5) {
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
                            .fill(Theme.divineInset)
                    }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.divineCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.divineCardStroke, lineWidth: 0.8)
        }
    }

    // MARK: - 顶部倒计时与控制卡

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 7, height: 7)
                        Text(statusTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        if manager.completedTodayCount > 0 {
                            Text("· 今日已歇 \(manager.completedTodayCount) 次")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }

                    Text(primaryTimerText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(settings.restReminderEnabled ? Color.primary : Theme.textTertiary)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $settings.restReminderEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("开启或关闭定时休息提醒")
            }

            HStack(spacing: 8) {
                Button {
                    manager.triggerNow()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 11))
                        Text("立即弹窗提醒")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .frame(height: 29)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.accent)
                    }
                }
                .buttonStyle(.plain)
                .pointerCursor()

                if settings.restReminderEnabled {
                    controlButton(
                        title: manager.isPaused ? "继续" : "暂停",
                        icon: manager.isPaused ? "play.fill" : "pause.fill"
                    ) {
                        manager.togglePause()
                    }

                    controlButton(title: "重置", icon: "arrow.counterclockwise") {
                        manager.resetCountdown()
                    }
                }

                Spacer(minLength: 0)
            }

            Hairline()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("提醒间隔")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 54, alignment: .leading)

                    HStack(spacing: 4) {
                        ForEach(intervalOptions, id: \.self) { mins in
                            let selected = settings.restIntervalMinutes == mins
                            Button {
                                settings.restIntervalMinutes = mins
                            } label: {
                                Text("\(mins)分")
                                    .font(.system(size: 10.5, weight: selected ? .semibold : .medium))
                                    .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(selected ? Theme.accent.opacity(0.13) : Theme.innerFill)
                                    }
                            }
                            .buttonStyle(.plain)
                            .pointerCursor()
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text("提醒策略")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 54, alignment: .leading)

                    Picker("", selection: $settings.restMode) {
                        ForEach(RestMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                }

                Text(settings.restMode.hint)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.leading, 62)

                HStack(spacing: 14) {
                    Toggle("投屏时不自动弹出", isOn: $settings.restSuppressWhenCasting)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textSecondary)

                    Toggle("仅工作时段 (9–19点)", isOn: $settings.restWorkHoursOnly)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textSecondary)

                    Toggle("提示音", isOn: $settings.restSoundEnabled)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.divineCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.divineCardStroke, lineWidth: 0.8)
        }
    }

    private var statusDotColor: Color {
        if !settings.restReminderEnabled { return Theme.textTertiary }
        if manager.isSuppressedByCasting || manager.isPaused || manager.isOutsideWorkHours { return Theme.earnings }
        return Theme.jieqi
    }

    private var statusTitle: String {
        if !settings.restReminderEnabled { return "定时提醒已关闭" }
        if manager.activeSession != nil { return "正在休息中" }
        if manager.isSuppressedByCasting { return "\(manager.castingReason ?? "投屏中")，已自动静默" }
        if manager.isPaused { return "已暂停" }
        if manager.isOutsideWorkHours { return "非工作时段，已静默" }
        return "距离下次休息提醒"
    }

    private var primaryTimerText: String {
        if !settings.restReminderEnabled { return "已关闭" }
        if let session = manager.activeSession {
            return session.isCompleted ? "已完成" : session.formattedRemaining
        }
        if manager.isOutsideWorkHours { return "09:00 恢复" }
        return manager.formattedCountdown
    }

    // MARK: - 正在休息横幅

    private func activeBreakBanner(_ session: ActiveRestSession) -> some View {
        HStack(spacing: 10) {
            Image(systemName: session.isCompleted ? "checkmark.circle.fill" : session.activity.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(session.isCompleted ? Theme.jieqi : session.activity.category.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.isCompleted ? "休息完成：\(session.activity.title)" : "正在进行：\(session.activity.title)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(session.isCompleted ? "状态已回血，继续轻松推进" : "剩余 \(session.formattedRemaining)，彻底放空大脑")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 6)

            if session.isCompleted {
                Button("好的") {
                    manager.cancelBreak()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.jieqi)
                .pointerCursor()
            } else {
                Button("完成") {
                    manager.finishBreak(autoDismissPopup: false)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(session.activity.category.tint)
                .pointerCursor()

                Button("取消") {
                    manager.cancelBreak()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .pointerCursor()
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(session.activity.category.tint.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(session.activity.category.tint.opacity(0.25), lineWidth: 0.7)
        }
    }

    // MARK: - 下午犯困急救组合

    private var emergencyCard: some View {
        let item = RestActivity.afternoonEmergency
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.earnings)
                Text(item.title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color.primary)
                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Theme.earnings)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Theme.earnings.opacity(0.16))
                        }
                }
                Spacer(minLength: 4)
                Button {
                    manager.startBreak(item)
                    RestPopupWindow.show(manager: manager)
                } label: {
                    Text("马上急救 \(item.durationLabel)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.earnings)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Theme.earnings.opacity(0.16))
                        }
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }

            Text(item.detail)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                ForEach(item.steps) { step in
                    Text("\(step.id). \(step.title)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Theme.innerFill)
                        }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.earnings.opacity(manager.isAfternoon ? 0.11 : 0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    previewActivity.id == item.id
                        ? Theme.earnings.opacity(0.6)
                        : Theme.earnings.opacity(manager.isAfternoon ? 0.30 : 0.16),
                    lineWidth: previewActivity.id == item.id ? 1.2 : 0.7
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            previewActivity = item
        }
        .pointerCursor()
    }

    // MARK: - 分类列表

    private func categorySection(_ category: RestCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(category.tint)
                Text(category.sectionTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.primary)
            }
            .padding(.top, 4)

            if let note = category.sectionNote {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ForEach(RestActivity.items(in: category)) { item in
                    activityCard(item)
                }
            }
        }
    }

    private func activityCard(_ item: RestActivity) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.category.tint)
                    .frame(width: 24, height: 24)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(item.category.tint.opacity(0.12))
                    }

                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary)

                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Theme.jieqi)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Theme.jieqi.opacity(0.14))
                        }
                }

                Spacer(minLength: 6)

                Button {
                    manager.startBreak(item)
                    RestPopupWindow.show(manager: manager)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8.5))
                        Text("歇 \(item.durationLabel)")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(item.category.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule(style: .continuous)
                            .fill(item.category.tint.opacity(0.12))
                    }
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }

            Text(item.detail)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                ForEach(item.steps) { step in
                    Text("\(step.id). \(step.title)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Theme.innerFill)
                        }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.divineCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    previewActivity.id == item.id ? item.category.tint.opacity(0.55) : Theme.divineCardStroke,
                    lineWidth: previewActivity.id == item.id ? 1.2 : 0.7
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onTapGesture {
            previewActivity = item
        }
        .pointerCursor()
    }

    private func controlButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 29)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.innerFill)
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}
