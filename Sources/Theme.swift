import SwiftUI
import AppKit

/// gofree 主题体系：海天青蓝 × 晨曦暖金（工作的目的是获得自由）
enum Theme {
    // 主色：海天青蓝（清醒专注 × 辽阔海天）
    static let accent = dynamic(light: rgb(14, 116, 168), dark: rgb(68, 178, 224))       // #0E74A8 / #44B2E0
    // 晨曦暖金：日出与收获的自由微光（同时用于美股财报与急救/高亮）
    static let sunrise = dynamic(light: rgb(186, 112, 16), dark: rgb(245, 188, 78))      // #BA7010 / #F5BC4E
    static let earnings = sunrise
    // 海风青翠：节气与离座呼吸
    static let jieqi = dynamic(light: rgb(14, 124, 102), dark: rgb(78, 212, 178))        // #0E7C66 / #4ED4B2
    // 朝霞珊瑚：节日、周末与休假角标
    static let festival = dynamic(light: rgb(202, 68, 54), dark: rgb(255, 144, 128))
    static let weekend = dynamic(light: rgb(182, 56, 46), dark: rgb(255, 130, 114))
    static let rest = dynamic(light: rgb(224, 88, 72), dark: rgb(255, 132, 116))
    static let work = dynamic(light: rgb(32, 126, 184), dark: rgb(104, 192, 240))

    /// 弹窗底色：浅色为清透晨雾白，深色为深海午夜青灰
    static let surface: Color = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0.04, green: 0.08, blue: 0.13, alpha: 0.54)
            : NSColor(srgbRed: 0.96, green: 0.985, blue: 1.0, alpha: 0.62)
    })
    /// 详情卡片
    static let cardFill = dynamic(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.94),
        dark: NSColor(srgbRed: 0.68, green: 0.84, blue: 0.98, alpha: 0.10)
    )
    static let cardStroke = dynamic(
        light: NSColor(srgbRed: 0.05, green: 0.24, blue: 0.38, alpha: 0.08),
        dark: NSColor(srgbRed: 0.56, green: 0.82, blue: 0.98, alpha: 0.14)
    )
    /// 浮在内容之上的不透明卡片（悬停解释卡、3D 底部条）
    static let cardSolid = dynamic(
        light: NSColor(srgbRed: 0.99, green: 0.995, blue: 1.0, alpha: 1),
        dark: rgb(26, 38, 52)
    )
    static let cardSolidStroke = dynamic(
        light: NSColor(srgbRed: 0.05, green: 0.24, blue: 0.38, alpha: 0.11),
        dark: NSColor(srgbRed: 0.56, green: 0.82, blue: 0.98, alpha: 0.20)
    )
    /// 仪表盘小卡片（天气、休息条、功能按钮）
    static let tileFill = dynamic(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.78),
        dark: NSColor(srgbRed: 0.68, green: 0.84, blue: 0.98, alpha: 0.08)
    )
    static let tileStroke = dynamic(
        light: NSColor(srgbRed: 0.05, green: 0.24, blue: 0.38, alpha: 0.07),
        dark: NSColor(srgbRed: 0.56, green: 0.82, blue: 0.98, alpha: 0.12)
    )
    static let innerFill = dynamic(
        light: NSColor(srgbRed: 0.05, green: 0.28, blue: 0.44, alpha: 0.045),
        dark: NSColor(srgbRed: 0.68, green: 0.86, blue: 1.0, alpha: 0.07)
    )
    static let hairline = dynamic(
        light: NSColor(srgbRed: 0.05, green: 0.24, blue: 0.38, alpha: 0.08),
        dark: NSColor(srgbRed: 0.56, green: 0.82, blue: 0.98, alpha: 0.13)
    )
    /// 次要 / 三级文字
    static let textSecondary = dynamic(
        light: NSColor(srgbRed: 0.08, green: 0.16, blue: 0.24, alpha: 0.68),
        dark: NSColor(srgbRed: 0.88, green: 0.94, blue: 1.0, alpha: 0.78)
    )
    static let textTertiary = dynamic(
        light: NSColor(srgbRed: 0.08, green: 0.16, blue: 0.24, alpha: 0.54),
        dark: NSColor(srgbRed: 0.78, green: 0.88, blue: 0.98, alpha: 0.58)
    )
    /// 星期标题
    static let weekdayHeader = dynamic(
        light: NSColor(srgbRed: 0.08, green: 0.18, blue: 0.28, alpha: 0.58),
        dark: NSColor(srgbRed: 0.82, green: 0.90, blue: 0.98, alpha: 0.62)
    )
    static let hoverFill = dynamic(
        light: NSColor(srgbRed: 0.05, green: 0.36, blue: 0.56, alpha: 0.07),
        dark: NSColor(srgbRed: 0.40, green: 0.76, blue: 0.98, alpha: 0.10)
    )

    // MARK: 独立窗口（占一事 / 定时休息：统一海天青蓝 × 晨曦暖金）

    static let divineAccent = accent
    /// 清透海雾白 / 深海午夜青
    static let divineSurface = dynamic(light: rgb(242, 247, 250), dark: rgb(16, 24, 34))
    /// 卡片底色
    static let divineCard = dynamic(light: rgb(255, 255, 255), dark: rgb(24, 35, 49))
    static let divineCardStroke = dynamic(
        light: NSColor(srgbRed: 0.06, green: 0.26, blue: 0.40, alpha: 0.09),
        dark: NSColor(srgbRed: 0.54, green: 0.82, blue: 0.98, alpha: 0.13)
    )
    /// 柔和内嵌容器（输入框、六爻卡、3D 舞台）
    static let divineInset = dynamic(light: rgb(233, 241, 246), dark: rgb(30, 44, 62))
    static let divineHighlight = dynamic(
        light: NSColor(srgbRed: 14/255, green: 116/255, blue: 168/255, alpha: 0.075),
        dark: NSColor(srgbRed: 68/255, green: 178/255, blue: 224/255, alpha: 0.14)
    )
    /// 正文层级
    static let divineInk = dynamic(light: rgb(16, 28, 38), dark: rgb(238, 245, 252))
    static let divineInkSecondary = dynamic(light: rgb(74, 96, 114), dark: rgb(164, 186, 206))
    static let divineInkTertiary = dynamic(light: rgb(118, 138, 154), dark: rgb(116, 140, 162))
    static let divineHairline = dynamic(
        light: NSColor(srgbRed: 0.06, green: 0.26, blue: 0.40, alpha: 0.09),
        dark: NSColor(srgbRed: 0.54, green: 0.82, blue: 0.98, alpha: 0.13)
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
            light: NSColor(srgbRed: 0.08, green: 0.18, blue: 0.28, alpha: 0.60),
            dark: NSColor(srgbRed: 0.82, green: 0.90, blue: 0.98, alpha: 0.66)
        )
        }
    }
}
