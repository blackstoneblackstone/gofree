import SwiftUI
import AppKit

/// 配置中心窗口（菜单栏 App 没有标准设置场景，这里手动开一个窗口）
@MainActor
enum SettingsWindow {

    private static var window: NSWindow?

    static func isSettingsWindow(_ candidate: NSWindow) -> Bool {
        window === candidate
    }

    static func open() {
        open(calendarService: .shared)
    }

    static func open(calendarService: CalendarService) {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = SettingsView(settings: AppSettings.shared, calendarService: calendarService)
        let hosting = NSHostingView(rootView: root)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "gofree 设置"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}
