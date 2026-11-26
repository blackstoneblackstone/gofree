import SwiftUI
import AppKit

extension View {
    /// 悬停时显示手型光标
    func pointerCursor() -> some View {
        onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
