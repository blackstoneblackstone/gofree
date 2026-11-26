import SwiftUI
import AppKit

enum Theme {
    // 主色：与图标主体的蓝一致（深色模式整体提亮一档，避免在深底上发闷）
    static let accent = dynamic(light: rgb(43, 98, 245), dark: rgb(79, 131, 255))      // #2B62F5 / #4F83FF
    static let jieqi = dynamic(light: rgb(15, 112, 72), dark: rgb(99, 214, 160))      // 节气绿 4.98:1
    static let festival = dynamic(light: rgb(196, 52, 42), dark: rgb(255, 148, 134))  // 节日红 5.24:1 / 深色 4.63:1
    static let weekend = dynamic(light: rgb(170, 40, 32), dark: rgb(255, 123, 110))   // 周末红 5.05:1
    static let rest = dynamic(light: rgb(233, 90, 76), dark: rgb(255, 122, 108))
    static let work = dynamic(light: rgb(70, 120, 236), dark: rgb(127, 168, 255))
    /// 美股财报日（网格小圆点）
    static let earnings = dynamic(light: rgb(146, 92, 12), dark: rgb(240, 183, 88))

    /// 弹窗底色：在毛玻璃上再压一层系统底色，避免整块灰糊成一片
    /// 深色下压得更狠，否则中灰底会把所有小字糊掉（毛玻璃本身在深色下就偏亮）
    static let surface: Color = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(white: 0, alpha: 0.42) : NSColor.windowBackgroundColor.withAlphaComponent(0.55)
    })
    /// 详情卡片：比底色再亮一档，形成清晰的层次（深色模式下用白色叠层而不是更黑）
    static let cardFill = dynamic(light: NSColor(white: 1, alpha: 0.92), dark: NSColor(white: 1, alpha: 0.11))
    static let cardStroke = dynamic(light: NSColor(white: 0, alpha: 0.07), dark: NSColor(white: 1, alpha: 0.11))
    /// 浮在内容之上的卡片（悬停解释卡）：必须完全不透明，否则下面的字会透上来
    static let cardSolid = dynamic(light: NSColor.white, dark: NSColor(white: 0.2, alpha: 1))
    static let cardSolidStroke = dynamic(light: NSColor(white: 0, alpha: 0.1), dark: NSColor(white: 1, alpha: 0.18))
    /// 仪表盘小卡片：比详情卡更淡，避免和主卡片抢层次
    static let tileFill = dynamic(light: NSColor(white: 1, alpha: 0.72), dark: NSColor(white: 1, alpha: 0.08))
    static let tileStroke = dynamic(light: NSColor(white: 0, alpha: 0.06), dark: NSColor(white: 1, alpha: 0.1))
    static let innerFill = dynamic(light: NSColor(white: 0, alpha: 0.04), dark: NSColor(white: 1, alpha: 0.06))
    static let hairline = dynamic(light: NSColor(white: 0, alpha: 0.08), dark: NSColor(white: 1, alpha: 0.12))
    /// 次要 / 三级文字：深色下不依赖系统 .secondary/.tertiary 的固定透明度，否则压在灰底上看不清
    static let textSecondary = dynamic(light: NSColor(white: 0, alpha: 0.66), dark: NSColor(white: 1, alpha: 0.76))
    static let textTertiary = dynamic(light: NSColor(white: 0, alpha: 0.56), dark: NSColor(white: 1, alpha: 0.58))
    /// 星期标题：10pt 小字，深色下要比正文更实
    static let weekdayHeader = dynamic(light: NSColor(white: 0, alpha: 0.58), dark: NSColor(white: 1, alpha: 0.6))
    static let hoverFill = dynamic(light: NSColor(white: 0, alpha: 0.065), dark: NSColor(white: 1, alpha: 0.08))

    // MARK: 占一事（统一现代毛玻璃 · 靛蓝主色）
    // 与主日历保持同一套现代 macOS 视觉语言：清透底色 + 靛蓝主色 + 清晰层次

    /// 占一事主色：与全局主色一致的现代靛蓝
    static let divineAccent = accent
    /// 现代清透底色（与弹窗协调，浅色冷净雾白，深色沉稳深灰）
    static let divineSurface = dynamic(light: rgb(245, 246, 250), dark: rgb(26, 27, 32))
    /// 现代卡片底色
    static let divineCard = dynamic(light: rgb(255, 255, 255), dark: rgb(36, 38, 45))
    static let divineCardStroke = dynamic(light: NSColor(srgbRed: 0.1, green: 0.14, blue: 0.25, alpha: 0.08),
                                          dark: NSColor(srgbRed: 0.9, green: 0.93, blue: 1, alpha: 0.10))
    /// 柔和内嵌容器（输入框、六爻卡、切换槽、3D 动画舞台）
    static let divineInset = dynamic(light: rgb(238, 241, 248), dark: rgb(44, 47, 56))
    static let divineHighlight = dynamic(light: NSColor(srgbRed: 43/255, green: 98/255, blue: 245/255, alpha: 0.065),
                                         dark: NSColor(srgbRed: 79/255, green: 131/255, blue: 255/255, alpha: 0.13))
    /// 正文层级
    static let divineInk = dynamic(light: rgb(22, 24, 30), dark: rgb(242, 244, 248))
    static let divineInkSecondary = dynamic(light: rgb(88, 94, 108), dark: rgb(172, 178, 192))
    static let divineInkTertiary = dynamic(light: rgb(134, 140, 154), dark: rgb(124, 130, 145))
    static let divineHairline = dynamic(light: NSColor(srgbRed: 0.1, green: 0.14, blue: 0.25, alpha: 0.08),
                                        dark: NSColor(srgbRed: 0.9, green: 0.93, blue: 1, alpha: 0.10))

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    /// 随外观切换的颜色
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    static func labelColor(_ kind: LabelKind) -> Color {
        switch kind {
        case .jieqi: return jieqi
        case .festival: return festival
        case .lunar: return dynamic(light: NSColor(white: 0, alpha: 0.6), dark: NSColor(white: 1, alpha: 0.64))
        }
    }
}
