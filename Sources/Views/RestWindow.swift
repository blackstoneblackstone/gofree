import AppKit
import SwiftUI

/// 「定时休息」主窗口：倒计时控制、提醒策略设置与完整休息指南
@MainActor
enum RestWindow {

    private static var window: NSWindow?

    static func isRestWindow(_ candidate: NSWindow) -> Bool {
        window === candidate
    }

    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        dismissMenuBarWindow()
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = RestGuideView(
            manager: RestReminderManager.shared,
            settings: AppSettings.shared
        )
        let hosting = NSHostingView(rootView: root)
        let size = NSSize(width: 448, height: 640)
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "gofree · 定时休息"
        window.minSize = NSSize(width: 420, height: 480)
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private static func dismissMenuBarWindow() {
        for candidate in NSApp.windows where candidate.isVisible {
            if candidate === window { continue }
            if SettingsWindow.isSettingsWindow(candidate) { continue }
            if ExpandedWindow.isExpandedWindow(candidate) { continue }
            if DivinationWindow.isDivinationWindow(candidate) { continue }
            if RestPopupWindow.isPopupWindow(candidate) { continue }
            candidate.orderOut(nil)
        }
    }
}
