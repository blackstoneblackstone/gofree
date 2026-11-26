import SwiftUI
import AppKit

/// 放大视图：一个独立窗口，并排展示连续两个月
@MainActor
enum ExpandedWindow {

    private static var window: NSWindow?

    static func open(store: AlmanacStore, calendarService: CalendarService) {
        NSApp.activate(ignoringOtherApps: true)
        dismissMenuBarWindow()
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = ExpandedCalendarView(store: store, calendarService: calendarService)
        let hosting = NSHostingView(rootView: root)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "gofree · 连续两个月"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    /// 放大时先把菜单栏浮窗收起来：本 App 只会创建「放大窗口」和「设置窗口」两个窗口，
    /// 其余可见窗口就是 MenuBarExtra 的浮窗，直接 orderOut（不依赖它的层级/类名）
    static func isExpandedWindow(_ candidate: NSWindow) -> Bool { window === candidate }

    static func dismissMenuBarWindow() {
        for window in NSApp.windows where window.isVisible {
            if window === self.window { continue }
            if SettingsWindow.isSettingsWindow(window) { continue }
            if DivinationWindow.isDivinationWindow(window) { continue }
            window.orderOut(nil)
        }
    }
}
