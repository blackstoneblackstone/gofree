import AppKit
import CoreGraphics
import Foundation

/// 用真实 gofree @2x 截图 + 原生 PingFang SC + SF Symbols 合成 5 张 1920×1080（严格 16:9）功能介绍图。
/// 用法：swift tools/compose_banners.swift <real_shots_dir>

struct FeatureBullet {
    let symbol: String
    let tint: NSColor
    let title: String
    let subtitle: String
}

struct PlacedShot {
    let path: String
    let rect: NSRect
    let cornerRadius: CGFloat
    let shadowAlpha: CGFloat
    let borderAlpha: CGFloat
    let isDark: Bool
}

struct BannerSpec {
    let outputPath: String
    let accentA: NSColor
    let accentB: NSColor
    let badgeIcon: String
    let badgeText: String
    let title: String
    let subtitle: String
    let bullets: [FeatureBullet]
    let shots: [PlacedShot]
}

let W: CGFloat = 1920
let H: CGFloat = 1080

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
    NSColor(srgbRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

func makeBitmapContext() -> (NSBitmapImageRep, CGContext) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(W),
        pixelsHigh: Int(H),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: W, height: H)
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let cg = nsCtx.cgContext
    cg.interpolationQuality = .high
    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    return (rep, cg)
}

func drawBackdrop(cg: CGContext, accentA: NSColor, accentB: NSColor) {
    let cs = CGColorSpaceCreateDeviceRGB()
    // 奶白工业风柔暖渐变底色（与 ESC 键帽质感呼应）
    let baseColors = [
        rgba(250, 248, 244).cgColor,
        rgba(247, 245, 249).cgColor,
        rgba(244, 248, 243).cgColor
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: baseColors, locations: [0, 0.5, 1]) {
        cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])
    }

    // 三个年轻电光氛围光斑
    let blobs: [(CGPoint, CGFloat, NSColor, CGFloat)] = [
        (CGPoint(x: 260, y: H - 160), 620, accentA, 0.17),
        (CGPoint(x: W - 240, y: H - 220), 680, accentB, 0.20),
        (CGPoint(x: W - 460, y: 180), 640, accentA, 0.14)
    ]
    for (center, radius, color, alpha) in blobs {
        let cols = [color.withAlphaComponent(alpha).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        if let rad = CGGradient(colorsSpace: cs, colors: cols, locations: [0, 1]) {
            cg.drawRadialGradient(rad, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsBeforeStartLocation])
        }
    }
}

func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor, maxWidth: CGFloat? = nil) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let str = NSAttributedString(string: text, attributes: attrs)
    if let maxWidth {
        str.draw(in: NSRect(x: point.x, y: point.y, width: maxWidth, height: 140))
    } else {
        str.draw(at: point)
    }
}

func drawSymbol(_ name: String, in rect: NSRect, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    guard let raw = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
    let tinted = NSImage(size: raw.size)
    tinted.lockFocus()
    color.set()
    let imgRect = NSRect(origin: .zero, size: raw.size)
    raw.draw(in: imgRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    imgRect.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let aspect = raw.size.width / max(1, raw.size.height)
    var target = rect
    if aspect > 1 {
        let h = rect.width / aspect
        target = NSRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h)
    } else {
        let w = rect.height * aspect
        target = NSRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: rect.height)
    }
    tinted.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)
}

func drawShot(_ shot: PlacedShot, cg: CGContext) {
    guard let img = NSImage(contentsOfFile: shot.path) else {
        fputs("⚠️ 无法读取截图: \(shot.path)\n", stderr)
        return
    }
    let imgSize = img.size
    let aspect = imgSize.width / max(1, imgSize.height)
    // 按目标框等比适配，不拉伸不变形
    var fitRect = shot.rect
    if shot.rect.width / shot.rect.height > aspect {
        let w = shot.rect.height * aspect
        fitRect = NSRect(x: shot.rect.midX - w / 2, y: shot.rect.minY, width: w, height: shot.rect.height)
    } else {
        let h = shot.rect.width / aspect
        fitRect = NSRect(x: shot.rect.minX, y: shot.rect.midY - h / 2, width: shot.rect.width, height: h)
    }

    let path = NSBezierPath(roundedRect: fitRect, xRadius: shot.cornerRadius, yRadius: shot.cornerRadius)

    // 双层柔和立体投影
    cg.saveGState()
    let shadow1 = NSShadow()
    shadow1.shadowColor = NSColor(white: 0.04, alpha: shot.shadowAlpha)
    shadow1.shadowOffset = NSSize(width: 0, height: -22)
    shadow1.shadowBlurRadius = 48
    shadow1.set()
    (shot.isDark ? rgba(28, 30, 36) : NSColor.white).setFill()
    path.fill()
    cg.restoreGState()

    // 圆角裁切绘制真实 @2x 截图
    cg.saveGState()
    path.addClip()
    img.draw(in: fitRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    cg.restoreGState()

    // 精致细描边
    cg.saveGState()
    (shot.isDark ? NSColor(white: 1, alpha: shot.borderAlpha) : NSColor(white: 0, alpha: shot.borderAlpha)).setStroke()
    path.lineWidth = 1.5
    path.stroke()
    cg.restoreGState()
}

func renderFeatureBanner(_ spec: BannerSpec) {
    let (rep, cg) = makeBitmapContext()
    drawBackdrop(cg: cg, accentA: spec.accentA, accentB: spec.accentB)

    // 左侧信息区（x = 104, 宽度 ~680）
    let leftX: CGFloat = 104

    // 顶部胶囊徽章
    let badgeFont = NSFont(name: "PingFangSC-Semibold", size: 24) ?? .systemFont(ofSize: 24, weight: .semibold)
    let badgeSize = (spec.badgeText as NSString).size(withAttributes: [.font: badgeFont])
    let pillRect = NSRect(x: leftX, y: H - 196, width: badgeSize.width + 78, height: 52)
    let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 26, yRadius: 26)
    spec.accentA.withAlphaComponent(0.12).setFill()
    pillPath.fill()
    spec.accentA.withAlphaComponent(0.24).setStroke()
    pillPath.lineWidth = 1.2
    pillPath.stroke()

    drawSymbol(
        spec.badgeIcon,
        in: NSRect(x: pillRect.minX + 20, y: pillRect.minY + 13, width: 26, height: 26),
        pointSize: 22,
        weight: .semibold,
        color: spec.accentA
    )
    drawText(
        spec.badgeText,
        at: CGPoint(x: pillRect.minX + 54, y: pillRect.minY + 10),
        font: badgeFont,
        color: spec.accentA
    )

    // 大标题
    let titleFont = NSFont(name: "PingFangSC-Semibold", size: 68) ?? .systemFont(ofSize: 68, weight: .bold)
    drawText(spec.title, at: CGPoint(x: leftX, y: H - 308), font: titleFont, color: rgba(20, 24, 34))

    // 副标题
    let subFont = NSFont(name: "PingFangSC-Regular", size: 28) ?? .systemFont(ofSize: 28, weight: .regular)
    drawText(spec.subtitle, at: CGPoint(x: leftX, y: H - 364), font: subFont, color: rgba(78, 86, 104))

    // 4 个卖点图标行
    var rowY: CGFloat = H - 486
    for bullet in spec.bullets {
        let iconBox = NSRect(x: leftX, y: rowY, width: 62, height: 62)
        let boxPath = NSBezierPath(roundedRect: iconBox, xRadius: 16, yRadius: 16)
        NSColor.white.withAlphaComponent(0.86).setFill()
        boxPath.fill()
        bullet.tint.withAlphaComponent(0.20).setStroke()
        boxPath.lineWidth = 1.2
        boxPath.stroke()

        drawSymbol(
            bullet.symbol,
            in: NSRect(x: iconBox.minX + 16, y: iconBox.minY + 16, width: 30, height: 30),
            pointSize: 24,
            weight: .semibold,
            color: bullet.tint
        )

        let bTitleFont = NSFont(name: "PingFangSC-Semibold", size: 26) ?? .systemFont(ofSize: 26, weight: .semibold)
        let bSubFont = NSFont(name: "PingFangSC-Regular", size: 20) ?? .systemFont(ofSize: 20, weight: .regular)
        drawText(bullet.title, at: CGPoint(x: leftX + 82, y: rowY + 30), font: bTitleFont, color: rgba(24, 28, 38))
        drawText(bullet.subtitle, at: CGPoint(x: leftX + 82, y: rowY + 2), font: bSubFont, color: rgba(96, 104, 122))
        rowY -= 118
    }

    // 右侧真实 App 截图层叠展示
    for shot in spec.shots {
        drawShot(shot, cg: cg)
    }

    savePNG(rep, to: spec.outputPath)
}

func renderHeroBanner(projectRoot: String, shotsDir: String) {
    let (rep, cg) = makeBitmapContext()
    drawBackdrop(cg: cg, accentA: rgba(236, 78, 22), accentB: rgba(132, 226, 48))

    // 顶部左侧：长翅膀 ESC App 图标 + gofree 主标题与品牌理念
    let iconPath = "\(projectRoot)/design/icon-1024.png"
    if let icon = NSImage(contentsOfFile: iconPath) {
        let iconRect = NSRect(x: 84, y: H - 186, width: 102, height: 102)
        icon.draw(in: iconRect)
    }

    let brandFont = NSFont(name: "PingFangSC-Semibold", size: 52) ?? .systemFont(ofSize: 52, weight: .bold)
    let tagFont = NSFont(name: "PingFangSC-Regular", size: 24) ?? .systemFont(ofSize: 24, weight: .regular)
    drawText("gofree", at: CGPoint(x: 202, y: H - 142), font: brandFont, color: rgba(24, 20, 30))
    drawText("工作的目的是获得自由 · 原生 macOS 菜单栏日历 / 美股 / 易断 / 3D 定时休息", at: CGPoint(x: 202, y: H - 178), font: tagFont, color: rgba(92, 86, 102))

    // 四枚小胶囊特性标（电光橙 × 荧光青柠 × 电光紫）
    let pills = [
        ("calendar", "离线万年历", rgba(236, 78, 22)),
        ("chart.line.uptrend.xyaxis", "美股 S&P 500", rgba(196, 116, 8)),
        ("sparkles", "Blender 3D 占卦", rgba(104, 78, 226)),
        ("cup.and.saucer.fill", "3D 分步定时休息", rgba(42, 142, 52))
    ]
    var px: CGFloat = 92
    let pFont = NSFont(name: "PingFangSC-Medium", size: 19) ?? .systemFont(ofSize: 19, weight: .medium)
    for (sym, label, tint) in pills {
        let sz = (label as NSString).size(withAttributes: [.font: pFont])
        let r = NSRect(x: px, y: H - 256, width: sz.width + 60, height: 42)
        let p = NSBezierPath(roundedRect: r, xRadius: 21, yRadius: 21)
        NSColor.white.withAlphaComponent(0.84).setFill()
        p.fill()
        tint.withAlphaComponent(0.24).setStroke()
        p.lineWidth = 1.1
        p.stroke()
        drawSymbol(sym, in: NSRect(x: r.minX + 16, y: r.minY + 10, width: 22, height: 22), pointSize: 18, weight: .semibold, color: tint)
        drawText(label, at: CGPoint(x: r.minX + 44, y: r.minY + 8), font: pFont, color: rgba(30, 34, 46))
        px += r.width + 14
    }

    // 三大真实 App 窗口错落全景：
    // 左：真实浅色菜单栏日历弹窗
    // 中上：真实「占一事」Blender 3D 浑天仪窗口（浅色）
    // 右下：真实「定时休息」3D 分步倒计时浮窗（深色）
    let heroShots: [PlacedShot] = [
        PlacedShot(
            path: "\(shotsDir)/divine_idle_light.png",
            rect: NSRect(x: 580, y: 250, width: 820, height: 495),
            cornerRadius: 18,
            shadowAlpha: 0.16,
            borderAlpha: 0.10,
            isDark: false
        ),
        PlacedShot(
            path: "\(shotsDir)/cal_light.png",
            rect: NSRect(x: 84, y: 56, width: 468, height: 742),
            cornerRadius: 18,
            shadowAlpha: 0.20,
            borderAlpha: 0.10,
            isDark: false
        ),
        PlacedShot(
            path: "\(shotsDir)/rest_dark.png",
            rect: NSRect(x: 1424, y: 58, width: 420, height: 590),
            cornerRadius: 20,
            shadowAlpha: 0.28,
            borderAlpha: 0.18,
            isDark: true
        )
    ]
    for shot in heroShots {
        drawShot(shot, cg: cg)
    }

    savePNG(rep, to: "\(projectRoot)/design/feature-hero-16x9.png")
}

func savePNG(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("✗ 编码 PNG 失败: \(path)\n", stderr)
        exit(1)
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("✓ 已生成 1920x1080 真实截图介绍图: \(path)")
    } catch {
        fputs("✗ 写入失败: \(error)\n", stderr)
        exit(1)
    }
}

// MARK: - 主流程

let shotsDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp"
let projectRoot = FileManager.default.currentDirectoryPath

let indigo = rgba(236, 78, 22)     // 电光活力橙
let jade = rgba(42, 142, 52)       // 荧光青柠绿
let amber = rgba(196, 116, 8)      // 高能电光黄
let crimson = rgba(216, 46, 68)    // 潮酷绯红
let violet = rgba(104, 78, 226)    // 潮酷电光紫

// 0. 顶部总览 Hero 16:9
renderHeroBanner(projectRoot: projectRoot, shotsDir: shotsDir)

// 1. 离线万年历与传统黄历（真实 cal_light + expanded_dark）
renderFeatureBanner(BannerSpec(
    outputPath: "\(projectRoot)/design/feature-calendar-16x9.png",
    accentA: indigo,
    accentB: jade,
    badgeIcon: "calendar",
    badgeText: "gofree · macOS 菜单栏",
    title: "离线万年历与黄历",
    subtitle: "菜单栏常驻 · 公历农历节气一屏尽览",
    bullets: [
        FeatureBullet(symbol: "calendar.day.timeline.left", tint: indigo, title: "7×6 月历与两月放大视图", subtitle: "翻月纯本地计算，零延迟切换"),
        FeatureBullet(symbol: "flag.fill", tint: crimson, title: "法定休 / 班角标", subtitle: "国务院放假调休清晰标注与倒计时"),
        FeatureBullet(symbol: "sparkles", tint: jade, title: "17 项传统黄历详情", subtitle: "干支、节气、星宿、彭祖百忌一键展开"),
        FeatureBullet(symbol: "cloud.sun.fill", tint: amber, title: "实时天气与系统日程", subtitle: "Open-Meteo 免 Key 缓存，可选接入日历")
    ],
    shots: [
        PlacedShot(path: "\(shotsDir)/expanded_dark.png", rect: NSRect(x: 1120, y: 185, width: 735, height: 420), cornerRadius: 18, shadowAlpha: 0.24, borderAlpha: 0.16, isDark: true),
        PlacedShot(path: "\(shotsDir)/cal_light.png", rect: NSRect(x: 790, y: 74, width: 520, height: 930), cornerRadius: 20, shadowAlpha: 0.22, borderAlpha: 0.10, isDark: false)
    ]
))

// 2. 美股财经日历（真实 preview-hover + preview-hover-dark）
renderFeatureBanner(BannerSpec(
    outputPath: "\(projectRoot)/design/feature-market-16x9.png",
    accentA: indigo,
    accentB: amber,
    badgeIcon: "chart.line.uptrend.xyaxis",
    badgeText: "gofree · 美股财经日历",
    title: "美股财报与宏观数据",
    subtitle: "S&P 500 智能过滤 · 北京时间精准换算",
    bullets: [
        FeatureBullet(symbol: "building.2.fill", tint: indigo, title: "标普 500 大公司财报", subtitle: "自动过滤成分股，展示盘前盘后与 EPS 预期"),
        FeatureBullet(symbol: "star.fill", tint: amber, title: "关键宏观经济事件", subtitle: "CPI、PCE、非农、FOMC 议息与五星重要度"),
        FeatureBullet(symbol: "book.fill", tint: jade, title: "悬停指标词典详解", subtitle: "悬停任意指标即看定义与对美股的真实影响"),
        FeatureBullet(symbol: "clock.badge.exclamationmark", tint: crimson, title: "休市与期权到期标记", subtitle: "纽交所休市、提前收盘与四巫日自动标注")
    ],
    shots: [
        PlacedShot(path: "\(projectRoot)/design/preview-hover-dark.png", rect: NSRect(x: 1320, y: 135, width: 520, height: 830), cornerRadius: 20, shadowAlpha: 0.26, borderAlpha: 0.16, isDark: true),
        PlacedShot(path: "\(projectRoot)/design/preview-hover.png", rect: NSRect(x: 825, y: 66, width: 540, height: 948), cornerRadius: 20, shadowAlpha: 0.22, borderAlpha: 0.10, isDark: false)
    ]
))

// 3. 「占一事」·《高岛易断》与 AI 解卦（真实 divine_idle_light + divine_result_dark）
renderFeatureBanner(BannerSpec(
    outputPath: "\(projectRoot)/design/feature-divine-16x9.png",
    accentA: violet,
    accentB: amber,
    badgeIcon: "sparkles",
    badgeText: "gofree · 占一事",
    title: "高岛易断与 AI 解卦",
    subtitle: "古法三变起卦 × Blender 3D × 原典切题研判",
    bullets: [
        FeatureBullet(symbol: "circle.hexagongrid.fill", tint: violet, title: "三种古法真随机起卦", subtitle: "高岛略筮、三枚铜钱、大衍之数（十八变）"),
        FeatureBullet(symbol: "cube.transparent.fill", tint: indigo, title: "Blender 3D 仪轨动效", subtitle: "八卦浑天仪、四十九策与古铜钱可 360° 旋转"),
        FeatureBullet(symbol: "text.book.closed.fill", tint: amber, title: "64 卦 384 爻原典切题", subtitle: "精准匹配商业、功名、家宅、出行等门类"),
        FeatureBullet(symbol: "wand.and.stars", tint: jade, title: "AI 结合原问题解卦", subtitle: "兼容 OpenAI 接口，API Key 仅存本机")
    ],
    shots: [
        PlacedShot(path: "\(shotsDir)/divine_result_dark.png", rect: NSRect(x: 1030, y: 310, width: 825, height: 715), cornerRadius: 18, shadowAlpha: 0.26, borderAlpha: 0.16, isDark: true),
        PlacedShot(path: "\(shotsDir)/divine_idle_light.png", rect: NSRect(x: 800, y: 68, width: 865, height: 520), cornerRadius: 18, shadowAlpha: 0.22, borderAlpha: 0.10, isDark: false)
    ]
))

// 4. 定时休息提醒（真实 rest_light + rest_dark）
renderFeatureBanner(BannerSpec(
    outputPath: "\(projectRoot)/design/feature-rest-reminder-16x9.png",
    accentA: indigo,
    accentB: jade,
    badgeIcon: "cup.and.saucer.fill",
    badgeText: "gofree · 定时休息",
    title: "定时休息提醒",
    subtitle: "0 破绽工位隐形休息 × 3 分钟离座断电",
    bullets: [
        FeatureBullet(symbol: "cube.fill", tint: indigo, title: "8 套 Blender 3D 动作演示", subtitle: "真 3D 动画小景支持拖拽旋转，一眼看懂做什么"),
        FeatureBullet(symbol: "list.number", tint: jade, title: "分步倒计时实时引导", subtitle: "3 步自动推进高亮当前进度，轻松放空大脑"),
        FeatureBullet(symbol: "arrow.triangle.2.circlepath", tint: violet, title: "智能交替策略 + 犯困急救", subtitle: "工位与离座交替，下午闭眼 2 分钟 + 冷水冲手腕"),
        FeatureBullet(symbol: "airplayvideo", tint: amber, title: "投屏时不自动弹出", subtitle: "会议共享屏幕与投影演示自动顺延不打扰")
    ],
    shots: [
        PlacedShot(path: "\(shotsDir)/rest_dark.png", rect: NSRect(x: 1300, y: 150, width: 540, height: 780), cornerRadius: 22, shadowAlpha: 0.28, borderAlpha: 0.18, isDark: true),
        PlacedShot(path: "\(shotsDir)/rest_light.png", rect: NSRect(x: 810, y: 80, width: 560, height: 860), cornerRadius: 22, shadowAlpha: 0.22, borderAlpha: 0.10, isDark: false)
    ]
))
