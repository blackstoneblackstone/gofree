import SwiftUI

/// 起卦动效所处的仪节阶段。
enum DivinerPhase: Equatable {
    /// 未起卦：柔和呼吸与 3D 轨道缓转
    case idle
    /// 起卦前第一步：净手澄心（深呼吸节奏）
    case cleanse
    /// 起卦前第二步：专念一事（凝神聚焦）
    case focus
    /// 起卦前第三步：合策默祷（四十九策聚光）
    case pray
    /// 起卦中：分二挂一，三变成爻
    case casting

    var symbolName: String {
        switch self {
        case .idle: return "sparkles"
        case .cleanse: return "wind"
        case .focus: return "scope"
        case .pray: return "hands.sparkles.fill"
        case .casting: return "circle.hexagongrid.fill"
        }
    }

    var badgeTitle: String {
        switch self {
        case .idle: return "准备起卦"
        case .cleanse: return "深呼吸 · 静心"
        case .focus: return "默念问题"
        case .pray: return "静默准备"
        case .casting: return "正在起卦"
        }
    }

    var tint: Color {
        switch self {
        case .idle: return Theme.accent
        case .cleanse: return Color(red: 0.14, green: 0.62, blue: 0.86)
        case .focus: return Theme.accent
        case .pray: return Theme.earnings
        case .casting: return Theme.accent
        }
    }

    var orbitSpeed: Double {
        switch self {
        case .idle: return 0.35
        case .cleanse: return 0.32
        case .focus: return 0.55
        case .pray: return 0.72
        case .casting: return 1.85
        }
    }
}

/// 现代 3D 透视流体星环 + 四十九策光束动效：自适应容器尺寸，可作主视觉中心或侧栏动效。
struct DivinerSceneView: View {
    let phase: DivinerPhase
    var showsBadge: Bool = true
    @State private var hovering = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = max(0.75, side / 184)

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let speed = phase.orbitSpeed
                // 净手澄心时放慢到 3.5 秒一次深呼吸
                let breathFreq: Double = phase == .cleanse ? 1.8 : (phase == .casting ? 4.0 : 1.5)
                let pulse = 0.5 + 0.5 * sin(t * breathFreq)

                ZStack {
                    // 1. 柔和多层环境呼吸光晕
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    phase.tint.opacity(0.26 + 0.14 * pulse),
                                    phase.tint.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 10 * scale,
                                endRadius: 84 * scale
                            )
                        )
                        .scaleEffect(0.90 + 0.14 * pulse)

                    // 2. 四十九策微光射线（呼应大衍五十、其用四十九）
                    Canvas { ctx, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let innerR = 42 * scale + (phase == .cleanse ? 6 * pulse * scale : 0)
                        let baseOuter = (phase == .pray ? 76 : 68) * scale
                        let count = 49
                        let rotation = t * 0.18 * speed
                        for i in 0..<count {
                            let angle = (Double(i) / Double(count)) * .pi * 2 + rotation
                            let wave = 0.5 + 0.5 * sin(Double(i) * 0.65 - t * 2.4)
                            let outerR = baseOuter + CGFloat(wave) * 10 * scale
                            var path = Path()
                            path.move(to: CGPoint(
                                x: center.x + cos(angle) * innerR,
                                y: center.y + sin(angle) * innerR
                            ))
                            path.addLine(to: CGPoint(
                                x: center.x + cos(angle) * outerR,
                                y: center.y + sin(angle) * outerR
                            ))
                            ctx.stroke(
                                path,
                                with: .color(phase.tint.opacity(0.10 + 0.20 * wave)),
                                style: StrokeStyle(lineWidth: 1.1 * scale, lineCap: .round)
                            )
                        }
                    }

                    // 3. 外层 3D 倾斜轨道环 1
                    orbitRing(
                        diameter: 136 * scale,
                        angle: t * 32 * speed,
                        tiltX: 62,
                        tiltY: 18,
                        lineWidth: 1.5 * scale,
                        opacity: 0.48,
                        dotSize: 6 * scale
                    )

                    // 4. 中层 3D 倾斜轨道环 2（反向旋转）
                    orbitRing(
                        diameter: 110 * scale,
                        angle: -t * 46 * speed + 90,
                        tiltX: 54,
                        tiltY: -34,
                        lineWidth: 1.25 * scale,
                        opacity: 0.36,
                        dotSize: 5 * scale
                    )

                    // 5. 内层律动虚线环
                    Circle()
                        .stroke(
                            phase.tint.opacity(0.28),
                            style: StrokeStyle(lineWidth: 1.3 * scale, lineCap: .round, dash: [3 * scale, 6 * scale])
                        )
                        .frame(width: 82 * scale, height: 82 * scale)
                        .rotationEffect(.degrees(t * 20 * speed))

                    // 6. 中心玻璃态核心 + 随阶段切换的 SF Symbol
                    ZStack {
                        Circle()
                            .fill(Theme.divineCard)
                            .frame(width: 58 * scale, height: 58 * scale)
                            .shadow(color: phase.tint.opacity(0.26), radius: 16 * scale, y: 4 * scale)
                            .overlay {
                                Circle()
                                    .strokeBorder(phase.tint.opacity(0.36), lineWidth: 1.2)
                            }

                        Image(systemName: phase.symbolName)
                            .font(.system(size: 24 * scale, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(phase.tint)
                            .contentTransition(.symbolEffect(.replace))
                            .scaleEffect(hovering ? 1.08 : (0.96 + 0.08 * pulse))
                    }
                    .offset(y: sin(t * 1.9) * 3 * scale)

                    // 7. 底部状态胶囊（可选）
                    if showsBadge {
                        VStack {
                            Spacer()
                            Text(phase.badgeTitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(phase.tint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(Theme.divineCard.opacity(0.92))
                                        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
                                }
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(phase.tint.opacity(0.22), lineWidth: 0.6)
                                }
                                .padding(.bottom, 10)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .animation(.spring(response: 0.45, dampingFraction: 0.78), value: phase)
            }
        }
        .onHover { hovering = $0 }
    }

    private func orbitRing(
        diameter: CGFloat,
        angle: Double,
        tiltX: Double,
        tiltY: Double,
        lineWidth: CGFloat,
        opacity: Double,
        dotSize: CGFloat
    ) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            phase.tint.opacity(opacity),
                            phase.tint.opacity(0.06),
                            phase.tint.opacity(opacity * 0.7),
                            phase.tint.opacity(0.06),
                            phase.tint.opacity(opacity)
                        ],
                        center: .center
                    ),
                    lineWidth: lineWidth
                )
            Circle()
                .fill(phase.tint)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: phase.tint.opacity(0.65), radius: 4)
                .offset(x: diameter / 2)
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(angle))
        .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
    }
}
