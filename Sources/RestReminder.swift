import AppKit
import Foundation
import Observation
import SwiftUI

/// 休息分类：留在工位（隐形休息）vs 离开工位（彻底断电）
enum RestCategory: String, CaseIterable, Identifiable, Codable {
    case atDesk
    case leaveDesk

    var id: String { rawValue }

    var sectionTitle: String {
        switch self {
        case .atDesk: return "一、留在工位：0 破绽的「隐形休息」"
        case .leaveDesk: return "二、离开工位：用「合理借口」彻底断电 3 分钟"
        }
    }

    var sectionNote: String? {
        switch self {
        case .atDesk:
            return nil
        case .leaveDesk:
            return "在工位上无论怎么伪装，大脑潜意识里还是有一根弦绷着。每隔 1–1.5 小时，最好给自己制造一次彻底脱离视线的空档："
        }
    }

    var shortBadge: String {
        switch self {
        case .atDesk: return "留在工位 · 隐形休息"
        case .leaveDesk: return "离开工位 · 断电 3 分钟"
        }
    }

    var icon: String {
        switch self {
        case .atDesk: return "desktopcomputer"
        case .leaveDesk: return "figure.walk"
        }
    }

    var tint: Color {
        switch self {
        case .atDesk: return Theme.accent
        case .leaveDesk: return Theme.jieqi
        }
    }
}

/// 提醒策略
enum RestMode: String, CaseIterable, Identifiable {
    case smart
    case atDeskOnly
    case leaveDeskOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .smart: return "智能交替"
        case .atDeskOnly: return "留在工位"
        case .leaveDeskOnly: return "离开工位"
        }
    }

    var hint: String {
        switch self {
        case .smart: return "工位隐形休息与离座断电交替提醒，每隔 1–1.5 小时离座一次"
        case .atDeskOnly: return "只提醒留在工位的 0 破绽隐形休息"
        case .leaveDeskOnly: return "每次都提醒离开工位彻底断电 3 分钟"
        }
    }
}

/// 单个执行步骤
struct RestStep: Identifiable, Hashable {
    let id: Int
    let title: String
    let instruction: String
    let durationSeconds: Int

    var durationLabel: String {
        if durationSeconds >= 60 && durationSeconds % 60 == 0 {
            return "\(durationSeconds / 60) 分钟"
        }
        return "\(durationSeconds) 秒"
    }
}

/// 单条休息建议
struct RestActivity: Identifiable, Hashable {
    let id: String
    let category: RestCategory
    let title: String
    let badge: String?
    let visualCue: String
    let detail: String
    let steps: [RestStep]
    let durationSeconds: Int
    let icon: String

    var durationLabel: String {
        let minutes = max(1, durationSeconds / 60)
        return "\(minutes) 分钟"
    }

    static let atDeskItems: [RestActivity] = [
        RestActivity(
            id: "chin-rest",
            category: .atDesk,
            title: "「托腮/扶额」伪装深思",
            badge: nil,
            visualCue: "指腹轻按眉头或太阳穴 · 视线放空",
            detail: "单手轻托下巴或扶着额头，顺势用指腹轻轻按压眉骨内侧（眉头）或太阳穴，视线落在一份打开的文档或屏幕空白处，大脑彻底放空。在外人看来你正在攻克难题，实际上你正在给眼周和神经减压。切记不要盯着别人看，别人可能在摸鱼。",
            steps: [
                RestStep(id: 1, title: "摆好深思姿势", instruction: "单手轻托下巴或扶着额头，视线落在文档或屏幕空白处（切记别盯着别人看）。", durationSeconds: 30),
                RestStep(id: 2, title: "指腹轻按减压", instruction: "顺势用指腹轻轻按压眉骨内侧（眉头）或太阳穴，轻柔打圈给眼周减压。", durationSeconds: 60),
                RestStep(id: 3, title: "彻底放空大脑", instruction: "保持姿势不动、松开咬紧的牙关，让紧绷的神经自然降频。", durationSeconds: 30)
            ],
            durationSeconds: 120,
            icon: "brain.head.profile"
        ),
        RestActivity(
            id: "under-desk-stretch",
            category: .atDesk,
            title: "桌子底下的肌肉松绑",
            badge: nil,
            visualCue: "桌下慢速勾脚尖 ↔ 绷脚背 · 收紧 5 秒放松",
            detail: "上半身保持正常坐姿不动，把注意力移到桌面以下：双脚悬空或着地，反复做慢速勾脚尖、绷脚背（促进久坐后的下肢血液循环）；或者刻意把大腿和臀部肌肉用力收紧 5 秒，再彻底松掉，重复 2–3 次，能瞬间带走很多紧绷感。",
            steps: [
                RestStep(id: 1, title: "慢速勾脚尖 ↔ 绷脚背", instruction: "上半身保持正常坐姿不动，桌下双脚悬空或着地，反复缓慢勾脚尖、绷脚背。", durationSeconds: 45),
                RestStep(id: 2, title: "大腿臀部收紧再松开", instruction: "刻意把大腿和臀部肌肉用力收紧 5 秒，再彻底松掉，重复 2–3 次。", durationSeconds: 45),
                RestStep(id: 3, title: "静置感受放松", instruction: "双脚平放回地面，感受下肢血液回流、全身紧绷感慢慢退散。", durationSeconds: 30)
            ],
            durationSeconds: 120,
            icon: "figure.seated.side"
        ),
        RestActivity(
            id: "ambient-noise",
            category: .atDesk,
            title: "戴降噪耳机，只听「环境音」",
            badge: nil,
            visualCue: "戴上降噪耳机 · 放一段雨声或低频白噪音",
            detail: "开放工位里，别人的键盘声和交谈声会持续消耗你的后台精力。戴上耳机开降噪，放一段雨声、风声或低频白噪音。哪怕眼睛还睁着，切断听觉干扰也能让大脑立刻安静一半。",
            steps: [
                RestStep(id: 1, title: "戴耳机开降噪", instruction: "戴上降噪耳机，瞬间切掉开放工位里的键盘声与交谈干扰。", durationSeconds: 20),
                RestStep(id: 2, title: "放一段环境音", instruction: "播放雨声、风声或低频白噪音，眼睛哪怕睁着也暂时移开复杂界面。", durationSeconds: 120),
                RestStep(id: 3, title: "跟着声音慢呼吸", instruction: "随白噪音节奏做 3–4 次平缓呼吸，让大脑后台彻底安静下来。", durationSeconds: 40)
            ],
            durationSeconds: 180,
            icon: "headphones"
        ),
        RestActivity(
            id: "low-energy-camouflage",
            category: .atDesk,
            title: "切去「低耗能伪装任务」",
            badge: nil,
            visualCue: "理一下桌面文件夹或废邮件 · 给大脑降频",
            detail: "脑子彻底转不动时，别硬盯着难题发呆，可以顺手整理一下桌面文件夹、清理废邮件，或者在纸上随便写点无关的字。手在动、屏幕在亮，但大脑已经从高负荷状态退出来了。",
            steps: [
                RestStep(id: 1, title: "暂时切离难题", instruction: "别硬盯着卡壳的任务发呆，先把高负荷窗口切到后台。", durationSeconds: 20),
                RestStep(id: 2, title: "做点零脑耗小事", instruction: "顺手整理桌面文件夹、清理废邮件，或在纸上随便写几行无关的字。", durationSeconds: 120),
                RestStep(id: 3, title: "轻量收尾切回", instruction: "手在动、屏幕在亮，等大脑退出高负荷后再从容切回正事。", durationSeconds: 40)
            ],
            durationSeconds: 180,
            icon: "folder.badge.gearshape"
        )
    ]

    static let leaveDeskItems: [RestActivity] = [
        RestActivity(
            id: "restroom-no-phone",
            category: .leaveDesk,
            title: "不带手机去洗手间",
            badge: "最管用",
            visualCue: "手机留工位 · 闭眼慢呼吸 2 分钟或冷水冲手腕",
            detail: "这是开放办公区里唯一 100% 绝对私密的空间。关键是别带手机，利用这 2–3 分钟纯粹闭眼做几次慢呼吸，或者用冷水冲一下手腕内侧，出来时脑子会清醒很多。",
            steps: [
                RestStep(id: 1, title: "把手机留在工位", instruction: "关键是绝不带手机，给自己 100% 私密且零信息干扰的空间。", durationSeconds: 20),
                RestStep(id: 2, title: "闭眼做几次慢呼吸", instruction: "纯粹闭上眼睛，吸气 4 秒、呼气 6 秒，彻底把大脑断电放空。", durationSeconds: 100),
                RestStep(id: 3, title: "冷水冲手腕内侧", instruction: "用冷水冲手腕内侧 15–20 秒再擦干，走出来时脑子立刻清醒。", durationSeconds: 60)
            ],
            durationSeconds: 180,
            icon: "door.left.hand.closed"
        ),
        RestActivity(
            id: "slow-water-refill",
            category: .leaveDesk,
            title: "刻意把「接水」拉长到 3 分钟",
            badge: nil,
            visualCue: "挑最远的饮水机慢慢接水 · 看窗外沉肩呼吸",
            detail: "挑一个离工位最远的茶水间或饮水机，故意放慢走路速度。等水流满杯子的时候，顺便看看窗外、做个小幅度的沉肩深呼吸，再慢慢走回来。",
            steps: [
                RestStep(id: 1, title: "挑最远的茶水间", instruction: "拿上杯子起身，刻意放慢脚步走向离工位最远的饮水机。", durationSeconds: 60),
                RestStep(id: 2, title: "看窗外沉肩呼吸", instruction: "等水流满杯子时望向窗外远方，顺便做两次小幅度的沉肩深呼吸。", durationSeconds: 70),
                RestStep(id: 3, title: "慢步端水回工位", instruction: "不赶时间，稳稳端着水慢慢走回工位，顺手喝两口水。", durationSeconds: 50)
            ],
            durationSeconds: 180,
            icon: "cup.and.saucer.fill"
        ),
        RestActivity(
            id: "stairwell-or-downstairs",
            category: .leaveDesk,
            title: "借着拿快递、接电话去楼梯间或楼下",
            badge: nil,
            visualCue: "去楼梯间伸个大懒腰 · 或下楼吹风晒 2 分钟太阳",
            detail: "楼梯间通常没人且安静，过去站 2 分钟、顺便大幅度伸个懒腰，或者下楼拿东西时顺带吹吹风、晒两分钟太阳，空间一换，紧绷感会掉得非常快。",
            steps: [
                RestStep(id: 1, title: "离开工位换空间", instruction: "借拿快递或接电话走出开放办公区，前往安静无人的楼梯间或楼下。", durationSeconds: 40),
                RestStep(id: 2, title: "伸懒腰 / 吹风晒太阳", instruction: "在楼梯间大幅度伸个懒腰，或在楼下吹吹风、晒两分钟太阳。", durationSeconds: 90),
                RestStep(id: 3, title: "松弛返回工位", instruction: "空间一换紧绷感很快消退，深吸一口气轻松回到工位。", durationSeconds: 50)
            ],
            durationSeconds: 180,
            icon: "figure.stairs"
        )
    ]

    static let afternoonEmergency = RestActivity(
        id: "afternoon-emergency",
        category: .leaveDesk,
        title: "下午犯困急救组合",
        badge: "比咖啡更快",
        visualCue: "不带手机闭眼 2 分钟 + 冷水冲手腕内侧",
        detail: "如果下午实在困得扛不住，把「不带手机去洗手间闭眼 2 分钟 + 冷水冲手腕」当成固定急救组合，通常比在工位上硬灌半杯咖啡见效更快。",
        steps: [
            RestStep(id: 1, title: "手机留桌立刻起身", instruction: "放下工作把手机留在工位，直接去洗手间。", durationSeconds: 15),
            RestStep(id: 2, title: "纯粹闭眼慢呼吸", instruction: "闭眼放空做 6–8 次深慢呼吸，不看屏幕、不想任何工作。", durationSeconds: 75),
            RestStep(id: 3, title: "冷水冲手腕内侧", instruction: "用冷水持续冲手腕内侧 20–30 秒，提神比硬灌半杯咖啡更快。", durationSeconds: 30)
        ],
        durationSeconds: 120,
        icon: "bolt.heart.fill"
    )

    static let allItems: [RestActivity] = atDeskItems + leaveDeskItems

    static func items(in category: RestCategory) -> [RestActivity] {
        switch category {
        case .atDesk: return atDeskItems
        case .leaveDesk: return leaveDeskItems
        }
    }
}

/// 正在进行的休息倒计时状态
struct ActiveRestSession: Equatable {
    let activity: RestActivity
    let totalSeconds: Int
    var remainingSeconds: Int
    var isCompleted: Bool = false

    var elapsedSeconds: Int {
        max(0, totalSeconds - remainingSeconds)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 1 }
        return min(1, max(0, Double(elapsedSeconds) / Double(totalSeconds)))
    }

    var formattedRemaining: String {
        let mins = max(0, remainingSeconds) / 60
        let secs = max(0, remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// 当前所处步骤的下标（随倒计时自动推进）
    var currentStepIndex: Int {
        guard !activity.steps.isEmpty else { return 0 }
        if isCompleted { return activity.steps.count - 1 }
        var acc = 0
        for (idx, step) in activity.steps.enumerated() {
            acc += step.durationSeconds
            if elapsedSeconds < acc {
                return idx
            }
        }
        return activity.steps.count - 1
    }

    /// 当前步骤剩余秒数
    var currentStepRemainingSeconds: Int {
        guard !activity.steps.isEmpty else { return remainingSeconds }
        if isCompleted { return 0 }
        var acc = 0
        for step in activity.steps {
            acc += step.durationSeconds
            if elapsedSeconds < acc {
                return max(0, acc - elapsedSeconds)
            }
        }
        return 0
    }

    /// 当前步骤完成进度 (0...1)
    var currentStepProgress: Double {
        guard !activity.steps.isEmpty else { return progress }
        if isCompleted { return 1 }
        let idx = currentStepIndex
        let step = activity.steps[idx]
        guard step.durationSeconds > 0 else { return 1 }
        let done = step.durationSeconds - currentStepRemainingSeconds
        return min(1, max(0, Double(done) / Double(step.durationSeconds)))
    }
}

/// 定时休息提醒管理器
@MainActor
@Observable
final class RestReminderManager {

    static let shared = RestReminderManager()

    /// 下一次触发时间（启用且未暂停时有效）
    private(set) var nextFireDate: Date?
    /// 距离下次提醒剩余秒数
    private(set) var secondsUntilNext: Int = 0
    /// 是否手动暂停
    private(set) var isPaused: Bool = false
    /// 当前推荐/展示的休息项目
    private(set) var currentActivity: RestActivity = RestActivity.atDeskItems[0]
    /// 正在进行的休息倒计时
    private(set) var activeSession: ActiveRestSession?
    /// 今日已完成休息次数
    private(set) var completedTodayCount: Int = 0
    /// 当前是否因投屏/共享屏幕自动静默
    private(set) var isSuppressedByCasting: Bool = false
    /// 静默原因（如「屏幕镜像投屏中」「会议共享屏幕中」）
    private(set) var castingReason: String?

    private var ticker: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var cycleIndex: Int = 0
    private var lastAtDeskIndex: Int = -1
    private var lastLeaveDeskIndex: Int = -1
    private var castCheckCounter: Int = 0
    private var started = false

    private enum DefaultsKey {
        static let completedDate = "restCompletedDate"
        static let completedCount = "restCompletedCount"
    }

    private let defaults: UserDefaults = {
        if let suite = ProcessInfo.processInfo.environment["GOFREE_DEFAULTS_SUITE"], !suite.isEmpty,
           let scoped = UserDefaults(suiteName: suite) {
            return scoped
        }
        return .standard
    }()

    private init() {
        loadTodayCount()
    }

    // MARK: - 生命周期

    func start() {
        guard !started else { return }
        started = true
        loadTodayCount()

        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSystemWake()
                }
            }
        }

        reschedule()
        startTicker()
    }

    /// 设置变化后重新调度
    func reschedule() {
        let settings = AppSettings.shared
        guard settings.restReminderEnabled else {
            nextFireDate = nil
            secondsUntilNext = 0
            return
        }
        if isPaused {
            nextFireDate = nil
            return
        }
        let interval = max(1, settings.restIntervalMinutes) * 60
        nextFireDate = Date().addingTimeInterval(TimeInterval(interval))
        secondsUntilNext = interval
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            nextFireDate = nil
        } else {
            let resumeSeconds = secondsUntilNext > 10 ? secondsUntilNext : max(1, AppSettings.shared.restIntervalMinutes) * 60
            nextFireDate = Date().addingTimeInterval(TimeInterval(resumeSeconds))
            secondsUntilNext = resumeSeconds
        }
    }

    func resetCountdown() {
        isPaused = false
        reschedule()
    }

    // MARK: - 触发与交互

    /// 立即弹出休息提醒浮窗
    /// - Parameter ignoreScreenSharing: 手动点击测试/「歇一下」时传 true；定时自动触发传 false（投屏时自动静默）
    func triggerNow(activity: RestActivity? = nil, playSound: Bool = true, ignoreScreenSharing: Bool = true) {
        if !ignoreScreenSharing, AppSettings.shared.restSuppressWhenCasting {
            let status = ScreenSharingDetector.currentStatus()
            isSuppressedByCasting = status.isCasting
            castingReason = status.reason
            if status.isCasting {
                // 投屏中不弹出，5 分钟后再静默重试
                nextFireDate = Date().addingTimeInterval(300)
                secondsUntilNext = 300
                return
            }
        }

        if let activity {
            currentActivity = activity
        } else {
            currentActivity = nextScheduledActivity()
        }
        activeSession = nil
        if playSound, AppSettings.shared.restSoundEnabled {
            playGentleSound(named: "Glass")
        }
        RestPopupWindow.show(manager: self)
    }

    /// 换一个建议（可选指定分类，不指定则切换另一个）
    func shuffleActivity(category: RestCategory? = nil) {
        let targetCategory: RestCategory
        if let category {
            targetCategory = category
        } else {
            switch AppSettings.shared.restMode {
            case .atDeskOnly: targetCategory = .atDesk
            case .leaveDeskOnly: targetCategory = .leaveDesk
            case .smart:
                // 换一个时在同一分类内轮换，或在两个分类间都可选
                targetCategory = currentActivity.category
            }
        }
        let pool = RestActivity.items(in: targetCategory)
        let candidates = pool.filter { $0.id != currentActivity.id }
        if let picked = candidates.randomElement() ?? pool.first {
            currentActivity = picked
        }
    }

    /// 切换到另一个分类的建议
    func switchCategory(_ category: RestCategory) {
        currentActivity = pickFromCategory(category)
    }

    /// 稍后提醒（默认 10 分钟）
    func snooze(minutes: Int = 10) {
        activeSession = nil
        isPaused = false
        let seconds = max(1, minutes) * 60
        nextFireDate = Date().addingTimeInterval(TimeInterval(seconds))
        secondsUntilNext = seconds
        RestPopupWindow.hide()
    }

    /// 关闭当前提醒并开始下一轮计时
    func dismissReminder() {
        activeSession = nil
        RestPopupWindow.hide()
        reschedule()
    }

    /// 开始某项休息的倒计时
    func startBreak(_ activity: RestActivity) {
        currentActivity = activity
        activeSession = ActiveRestSession(
            activity: activity,
            totalSeconds: activity.durationSeconds,
            remainingSeconds: activity.durationSeconds,
            isCompleted: false
        )
        // 休息期间暂停下一轮提醒计时，避免重叠
        nextFireDate = nil
    }

    /// 手动结束或自动完成当前休息
    func finishBreak(autoDismissPopup: Bool = false) {
        guard var session = activeSession else { return }
        if !session.isCompleted {
            session.remainingSeconds = 0
            session.isCompleted = true
            activeSession = session
            incrementTodayCount()
            if AppSettings.shared.restSoundEnabled {
                playGentleSound(named: "Tink")
            }
        }
        reschedule()

        if autoDismissPopup {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.4))
                if self.activeSession?.isCompleted == true {
                    self.activeSession = nil
                    RestPopupWindow.hide()
                }
            }
        }
    }

    /// 取消当前休息倒计时
    func cancelBreak() {
        activeSession = nil
        reschedule()
    }

    /// 预览截图辅助：选择指定休息项
    func previewSelect(_ activity: RestActivity) {
        currentActivity = activity
        activeSession = nil
    }

    /// 预览截图辅助：推进当前休息已过秒数
    func previewAdvanceElapsed(seconds: Int) {
        guard var session = activeSession else { return }
        session.remainingSeconds = max(1, session.totalSeconds - seconds)
        activeSession = session
    }

    // MARK: - 状态辅助

    var isAfternoon: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 13 && hour < 18
    }

    var isOutsideWorkHours: Bool {
        guard AppSettings.shared.restWorkHoursOnly else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 9 || hour >= 19
    }

    var formattedCountdown: String {
        let s = max(0, secondsUntilNext)
        let hours = s / 3600
        let mins = (s % 3600) / 60
        let secs = s % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }

    var compactCountdownLabel: String {
        let s = max(0, secondsUntilNext)
        if s < 60 {
            return "不足 1 分钟"
        }
        let mins = Int(ceil(Double(s) / 60.0))
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m == 0 ? "\(h) 小时后" : "\(h) 小时 \(m) 分后"
        }
        return "\(mins) 分钟后"
    }

    // MARK: - 内部调度

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        refreshTodayCountIfNeeded()

        // 每 3 秒检查一次投屏/共享屏幕状态，开销极低
        castCheckCounter += 1
        if castCheckCounter >= 3 {
            castCheckCounter = 0
            refreshCastingStatus()
        }

        // 1. 若正在休息倒计时
        if var session = activeSession, !session.isCompleted {
            if session.remainingSeconds > 1 {
                session.remainingSeconds -= 1
                activeSession = session
            } else {
                finishBreak(autoDismissPopup: RestPopupWindow.isVisible)
            }
            return
        }

        // 2. 正常提醒倒计时
        let settings = AppSettings.shared
        guard settings.restReminderEnabled, !isPaused else { return }

        // 若限制了工作时段且当前不在工作时段，则延后不弹出
        if isOutsideWorkHours {
            return
        }

        guard let target = nextFireDate else {
            reschedule()
            return
        }

        let remaining = Int(ceil(target.timeIntervalSinceNow))
        if remaining > 0 {
            secondsUntilNext = remaining
        } else {
            secondsUntilNext = 0
            nextFireDate = nil
            triggerNow(ignoreScreenSharing: false)
        }
    }

    private func refreshCastingStatus() {
        guard AppSettings.shared.restSuppressWhenCasting else {
            if isSuppressedByCasting {
                isSuppressedByCasting = false
                castingReason = nil
            }
            return
        }
        let status = ScreenSharingDetector.currentStatus()
        isSuppressedByCasting = status.isCasting
        castingReason = status.reason
    }

    private func handleSystemWake() {
        // 电脑睡眠唤醒后重新开始一轮，避免刚解锁就弹窗打扰
        if activeSession == nil, AppSettings.shared.restReminderEnabled, !isPaused {
            reschedule()
        }
    }

    private func nextScheduledActivity() -> RestActivity {
        let settings = AppSettings.shared
        let category: RestCategory
        switch settings.restMode {
        case .atDeskOnly:
            category = .atDesk
        case .leaveDeskOnly:
            category = .leaveDesk
        case .smart:
            // 智能交替：每隔 1–1.5 小时安排一次离座断电
            // 间隔 <= 45 分钟时：工位 -> 离座交替（每 2 次即 60–90 分钟离座一次）
            // 间隔 >= 60 分钟时：工位 -> 离座交替
            cycleIndex += 1
            category = (cycleIndex % 2 == 0) ? .leaveDesk : .atDesk
        }
        return pickFromCategory(category)
    }

    private func pickFromCategory(_ category: RestCategory) -> RestActivity {
        let items = RestActivity.items(in: category)
        switch category {
        case .atDesk:
            lastAtDeskIndex = (lastAtDeskIndex + 1) % items.count
            return items[lastAtDeskIndex]
        case .leaveDesk:
            lastLeaveDeskIndex = (lastLeaveDeskIndex + 1) % items.count
            return items[lastLeaveDeskIndex]
        }
    }

    private func playGentleSound(named name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = 0.45
            sound.play()
        }
    }

    // MARK: - 今日计数持久化

    private static func todayKey() -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }

    private func loadTodayCount() {
        let today = Self.todayKey()
        if defaults.string(forKey: DefaultsKey.completedDate) == today {
            completedTodayCount = defaults.integer(forKey: DefaultsKey.completedCount)
        } else {
            completedTodayCount = 0
        }
    }

    private func refreshTodayCountIfNeeded() {
        let today = Self.todayKey()
        if defaults.string(forKey: DefaultsKey.completedDate) != today, completedTodayCount != 0 {
            completedTodayCount = 0
        }
    }

    private func incrementTodayCount() {
        let today = Self.todayKey()
        if defaults.string(forKey: DefaultsKey.completedDate) != today {
            completedTodayCount = 1
        } else {
            completedTodayCount += 1
        }
        defaults.set(today, forKey: DefaultsKey.completedDate)
        defaults.set(completedTodayCount, forKey: DefaultsKey.completedCount)
    }
}
