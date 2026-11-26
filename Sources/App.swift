import SwiftUI
import AppKit
import Combine

@main
enum GofreeMain {
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.count > 1, arguments[1].hasPrefix("--") {
            let exitCode = MainActor.assumeIsolated { CLIRunner.run() }
            if let exitCode { exit(exitCode) }
        }
        GofreeApp.main()
    }
}

struct GofreeApp: App {
    @State private var store = AlmanacStore()
    @State private var calendarService = CalendarService.shared
    @State private var now = Date()
    @State private var showsMore = false

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init() {
        // 启动时套用保存的外观（跟随系统 / 浅色 / 深色）
        AppSettings.apply(AppSettings.shared.appearance)
        // 启动定时休息提醒调度
        RestReminderManager.shared.start()
        // 调试用：GOFREE_OPEN_ON_LAUNCH=settings / divine / rest / rest-popup，启动即开对应窗口
        // （两月视图需要 store，这里拿不到，就不支持了）
        if let target = ProcessInfo.processInfo.environment["GOFREE_OPEN_ON_LAUNCH"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                switch target {
                case "settings": SettingsWindow.open()
                case "divine": DivinationWindow.open()
                case "rest": RestWindow.open()
                case "rest-popup": RestReminderManager.shared.triggerNow(playSound: false)
                default: break
                }
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                store: store,
                calendarService: calendarService,
                onQuit: { NSApp.terminate(nil) },
                showsMore: $showsMore
            )
        } label: {
            Text(Self.statusText(for: now))
                .onReceive(minuteTimer) { tick in
                    now = tick
                    store.refreshToday()   // 跨天时跟上今天的月份与选中日
                }
        }
        .menuBarExtraStyle(.window)
    }

    /// 菜单栏文字，例如 "9/19 周六"
    static func statusText(for date: Date) -> String {
        let calendar = Calendar.gregorianMondayFirst
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        return "\(month)/\(day) \(shortWeekday(date))"
    }

    static func shortWeekday(_ date: Date) -> String {
        let names = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return names[max(1, min(7, date.isoWeekdayMondayFirst))]
    }
}