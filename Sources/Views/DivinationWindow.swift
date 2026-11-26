import SwiftUI
import AppKit

/// 「占一事」窗口。结果出来后内容会变高，所以由视图通过 onSizeChange 回调把尺寸推给窗口。
@MainActor
enum DivinationWindow {

    private static var window: NSWindow?
    private static let box = WindowBox()

    static func isDivinationWindow(_ candidate: NSWindow) -> Bool {
        window === candidate
    }

    /// - Parameters:
    ///   - previewQuestion: 预留问题文本（截图/自检用）
    ///   - previewResult: 预置结果，窗口直接按结果态定尺寸
    static func open(previewQuestion: String = "", previewResult: DivinationResult? = nil) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        dismissMenuBarWindow()
        if let window, previewResult == nil, previewQuestion.isEmpty {
            window.makeKeyAndOrderFront(nil)
            return
        }

        window?.orderOut(nil)
        box.window = nil

        let root = DivinationView(
            previewQuestion: previewQuestion,
            previewResult: previewResult,
            onSizeChange: { size in
                guard let window = box.window, size.height > 0 else { return }
                var frame = window.frame
                let chrome = window.frame.height - window.contentLayoutRect.height
                frame.size = NSSize(width: size.width, height: size.height + chrome)
                frame.origin.y = window.frame.maxY - frame.height
                window.setFrame(frame, display: true)
            }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: contentSize(previewResult: previewResult))

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "gofree 占一事"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        box.window = window
    }

    /// 和放大视图一样：先把 MenuBarExtra 的浮窗收起来，不然新窗口被压在它下面，
    /// 看起来就像「点了没反应」。只收浮窗，别把设置窗口、放大窗口连带关掉。
    private static func dismissMenuBarWindow() {
        for candidate in NSApp.windows where candidate.isVisible {
            if candidate === window { continue }
            if SettingsWindow.isSettingsWindow(candidate) { continue }
            if ExpandedWindow.isExpandedWindow(candidate) { continue }
            if RestWindow.isRestWindow(candidate) { continue }
            if RestPopupWindow.isPopupWindow(candidate) { continue }
            candidate.orderOut(nil)
        }
    }

    /// 量内容高度：与截图走同一条路径（设 frame → layout → fittingSize），
    /// 单独放着的 NSHostingView 不会自己布局，fittingSize 会是 0。
    static func contentSize(previewResult: DivinationResult?) -> NSSize {
        let hosting = NSHostingView(
            rootView: DivinationView(previewQuestion: "自检", previewResult: previewResult)
        )
        hosting.frame = NSRect(x: 0, y: 0, width: DivinationView.width, height: 900)
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        return NSSize(width: DivinationView.width, height: max(120, fitting.height))
    }
}

@MainActor
private final class WindowBox {
    weak var window: NSWindow?
}