import SwiftUI
import AppKit

/// gofree 主题体系：Teenage Engineering 潮酷工业风 · 电光活力橙 × 荧光青柠 × 奶白/深紫炭灰
enum Theme {
    // 主色：电光活力橙（对应 ESC 键帽主体，年轻明快、高辨识度）
    static let accent = dynamic(light: rgb(236, 78, 22), dark: rgb(255, 114, 56))       // #EC4E16 / #FF7238
    // 荧光青柠：对应 ESC 羽翼，用于节气、离座休息与完成态
    static let jieqi = dynamic(light: rgb(42, 142, 52), dark: rgb(156, 238, 66))        // #2A8E34 / #9CEE42
    // 高能电光黄：美股财报与犯困急救高亮
    static let sunrise = dynamic(light: rgb(196, 116, 8), dark: rgb(255, 206, 68))      // #C47408 / #FFCE44
    static let earnings = sunrise
    // 潮酷绯红：节日、周末与休假角标
    static let festival = dynamic(light: rgb(216, 46, 68), dark: rgb(255, 108, 128))
    static let weekend = dynamic(light: rgb(196, 40, 60), dark: rgb(255, 100, 118))
    static let rest = dynamic(light: rgb(234, 62, 74), dark: rgb(255, 114, 122))
    // 潮酷电光紫：调休班与工具辅助色
    static let work = dynamic(light: rgb(104, 78, 226), dark: rgb(162, 142, 255))

    /// 弹窗底色：浅色为键帽奶白米灰，深色为阳极氧化深紫炭灰
    static let surface: Color = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0.09, green: 0.08, blue: 0.13, alpha: 0.56)
            : NSColor(srgbRed: 0.98, green: 0.97, blue: 0.955, alpha: 0.64)
    })
    /// 详情卡片
    static let cardFill = dynamic(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95),
        dark: NSColor(srgbRed: 0.84, green: 0.80, blue: 0.98, alpha: 0.10)
    )
    static let cardStroke = dynamic(
        light: NSColor(srgbRed: 0.18, green: 0.14, blue: 0.24, alpha: 0.08),
        dark: NSColor(srgbRed: 0.82, green: 0.78, blue: 0.98, alpha: 0.14)
    )
    /// 浮在内容之上的不透明卡片（悬停解释卡、3D 底部条）
    static let cardSolid = dynamic(
        light: NSColor(srgbRed: 1, green: 0.996, blue: 0.99, alpha: 1),
        dark: rgb(38, 34, 50)
    )
    static let cardSolidStroke = dynamic(
        light: NSColor(srgbRed: 0.18, green: 0.14, blue: 0.24, alpha: 0.11),
        dark: NSColor(srgbRed: 0.82, green: 0.78, blue: 0.98, alpha: 0.20)
    )
    /// 仪表盘小卡片（天气、休息条、功能按钮）
    static let tileFill = dynamic(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.80),
        dark: NSColor(srgbRed: 0.84, green: 0.80, blue: 0.98, alpha: 0.08)
    )
    static let tileStroke = dynamic(
        light: NSColor(srgbRed: 0.18, green: 0.14, blue: 0.24, alpha: 0.07),
        dark: NSColor(srgbRed: 0.82, green: 0.78, blue: 0.98, alpha: 0.12)
    )
    static let innerFill = dynamic(
        light: NSColor(srgbRed: 0.18, green: 0.14, blue: 0.24, alpha: 0.045),
        dark: NSColor(srgbRed: 0.84, green: 0.80, blue: 0.98, alpha: 0.07)
    )
    static let hairline = dynamic(
        light: NSColor(srgbRed: 0.18, green: 0.14, blue: 0.24, alpha: 0.08),
        dark: NSColor(srgbRed: 0.82, green: 0.78, blue: 0.98, alpha: 0.13)
    )
    /// 次要 / 三级文字
    static let textSecondary = dynamic(
        light: NSColor(srgbRed: 0.14, green: 0.12, blue: 0.18, alpha: 0.68),
        dark: NSColor(srgbRed: 0.94, green: 0.92, blue: 0.98, alpha: 0.78)
    )
    static let textTertiary = dynamic(
        light: NSColor(srgbRed: 0.14, green: 0.12, blue: 0.18, alpha: 0.52),
        dark: NSColor(srgbRed: 0.84, green: 0.80, blue: 0.92, alpha: 0.58)
    )
    /// 星期标题
    static let weekdayHeader = dynamic(
        light: NSColor(srgbRed: 0.14, green: 0.12, blue: 0.18, alpha: 0.56),
        dark: NSColor(srgbRed: 0.88, green: 0.84, blue: 0.96, alpha: 0.62)
    )
    static let hoverFill = dynamic(
        light: NSColor(srgbRed: 236/255, green: 78/255, blue: 22/255, alpha: 0.07),
        dark: NSColor(srgbRed: 255/255, green: 114/255, blue: 56/255, alpha: 0.12)
    )

    // MARK: 独立窗口（占一事 / 定时休息：奶白米灰 / 深紫炭灰 + 电光橙点亮）

    static let divineAccent = accent
    static let divineSurface = dynamic(light: rgb(248, 246, 242), dark: rgb(24, 21, 32))
    static let divineCard = dynamic(light: rgb(255, 255, 255), dark: rgb(35, 31, 46))
    static let divineCardStroke = dynamic(
        light: NSColor(srgbRed: 0.18, green: 0.14, blue: 0.24, alpha: 0.09),
        dark: NSColor(srgbRed: 0.82, green: 0.78, blue: 0.98, alpha: 0.13)
    )
    static let divineInset = dynamic(light: rgb(241, 238, 233), dark: rgb(45, 40, 58))
    static let divineHighlight = dynamic(
        light: NSColor(srgbRed: 236/255, green: 78/255, blue: 22/255, alpha: 0.08),
        dark: NSColor(srgbRed: 255/255, green: 114/255, blue: 56/255, alpha: 0.15)
    )
    static let divineInk = dynamic(light: rgb(24, 20, 30), dark: rgb(246, 244, 250))
    static let divineInkSecondary = dynamic(light: rgb(92, 86, 102), dark: rgb(184, 178, 198))
    static let divineInkTertiary = dynamic(light: rgb(138, 132, 148), dark: rgb(134, 128, 148))
    static let divineHairline = dynamic(
        light: NSColor(srgbRed: 0.18, green: 0.14, blue: 0.24, alpha: 0.09),
        dark: NSColor(srgbRed: 0.82, green: 0.78, blue: 0.98, alpha: 0.13)
    )

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
        case .lunar: return dynamic(
            light: NSColor(srgbRed: 0.14, green: 0.12, blue: 0.18, alpha: 0.58),
            dark: NSColor(srgbRed: 0.88, green: 0.84, blue: 0.96, alpha: 0.66)
        )
        }
    }
}
