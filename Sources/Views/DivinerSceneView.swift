import AppKit
import SceneKit
import SwiftUI

/// 起卦动效所处的仪节阶段。
enum DivinerPhase: Equatable {
    /// 未起卦：现代八卦浑天仪缓转
    case idle
    /// 起卦前第一步：净手澄心（四十九策聚光呼吸）
    case cleanse
    /// 起卦前第二步：专念一事（凝神聚焦）
    case focus
    /// 起卦前第三步：合策默祷（四十九策聚光）
    case pray
    /// 起卦中：三枚外圆内方古铜钱动态起卦
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

    /// 对应的 Blender .usdz 3D 模型文件名
    var modelName: String {
        switch self {
        case .idle, .focus: return "divine-idle"
        case .cleanse, .pray: return "divine-ritual"
        case .casting: return "divine-casting"
        }
    }
}

/// 「占一事」Blender 5.3 真 3D（.usdz）仪轨动效舞台：
/// 随起卦阶段自动切换八卦浑天仪、四十九策聚光仪、三枚古铜钱起卦 3D 模型，支持鼠标拖拽旋转。
struct DivinerSceneView: View {
    let phase: DivinerPhase
    var showsBadge: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RadialGradient(
                    colors: [
                        phase.tint.opacity(0.18),
                        phase.tint.opacity(0.04),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.48),
                    startRadius: 8,
                    endRadius: 120
                )

                DivineUSDZViewRepresentable(modelName: phase.modelName)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsBadge {
                HStack(spacing: 5) {
                    Image(systemName: phase.symbolName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(phase.tint)
                    Text(phase.badgeTitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(Theme.divineCard.opacity(0.75))
                .overlay(alignment: .top) {
                    Hairline()
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: phase)
    }
}

// MARK: - SceneKit USDZ Loader

private struct DivineUSDZViewRepresentable: NSViewRepresentable {
    let modelName: String

    final class Coordinator {
        var currentModelName: String = ""
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        view.isPlaying = true
        view.loops = true
        context.coordinator.currentModelName = modelName
        view.scene = DivineUSDZLoader.loadScene(named: modelName)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        guard context.coordinator.currentModelName != modelName else { return }
        context.coordinator.currentModelName = modelName
        nsView.scene = DivineUSDZLoader.loadScene(named: modelName)
        nsView.isPlaying = true
    }
}

private enum DivineUSDZLoader {

    private static let studioEnvironmentImage: NSImage = {
        let size = NSSize(width: 256, height: 128)
        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            let colors = [
                NSColor(srgbRed: 0.16, green: 0.20, blue: 0.28, alpha: 1).cgColor,
                NSColor(srgbRed: 0.64, green: 0.74, blue: 0.88, alpha: 1).cgColor,
                NSColor(srgbRed: 0.98, green: 0.96, blue: 0.92, alpha: 1).cgColor,
                NSColor(srgbRed: 1.00, green: 0.99, blue: 0.97, alpha: 1).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.40, 0.75, 1.0]
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                ctx.drawLinearGradient(
                    grad,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }
        }
        image.unlockFocus()
        return image
    }()

    static func loadScene(named modelName: String) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        scene.lightingEnvironment.contents = studioEnvironmentImage
        scene.lightingEnvironment.intensity = 0.36

        let stage = SCNNode()
        scene.rootNode.addChildNode(stage)

        let url = Bundle.main.url(forResource: modelName, withExtension: "usdz", subdirectory: "DivineModels")
            ?? Bundle.main.url(forResource: modelName, withExtension: "usdz")

        if let url, let loaded = try? SCNScene(url: url, options: [
            .checkConsistency: false,
            .flattenScene: false
        ]) {
            let modelRoot = SCNNode()
            for child in loaded.rootNode.childNodes {
                modelRoot.addChildNode(child)
            }
            enableLoopingAnimations(in: modelRoot)

            let (minB, maxB) = modelRoot.boundingBox
            let center = SCNVector3(
                (minB.x + maxB.x) * 0.5,
                (minB.y + maxB.y) * 0.5,
                (minB.z + maxB.z) * 0.5
            )
            let size = SCNVector3(
                max(0.01, maxB.x - minB.x),
                max(0.01, maxB.y - minB.y),
                max(0.01, maxB.z - minB.z)
            )
            let maxDim = max(size.x, max(size.y, size.z))
            let fitScale = CGFloat(2.45 / maxDim)
            modelRoot.scale = SCNVector3(fitScale, fitScale, fitScale)
            modelRoot.position = SCNVector3(
                -center.x * fitScale,
                -center.y * fitScale,
                -center.z * fitScale
            )
            stage.addChildNode(modelRoot)
        }

        // 柔和展示台微幅摇摆
        let swayLeft = SCNAction.rotateTo(x: 0.02, y: -0.22, z: 0, duration: 4.2)
        swayLeft.timingMode = .easeInEaseOut
        let swayRight = SCNAction.rotateTo(x: -0.02, y: 0.22, z: 0, duration: 4.2)
        swayRight.timingMode = .easeInEaseOut
        stage.runAction(.repeatForever(.sequence([swayLeft, swayRight])))

        setupLighting(in: scene)
        setupCamera(in: scene)
        return scene
    }

    private static func enableLoopingAnimations(in node: SCNNode) {
        for key in node.animationKeys {
            if let player = node.animationPlayer(forKey: key) {
                player.animation.repeatCount = .greatestFiniteMagnitude
                player.animation.isRemovedOnCompletion = false
                player.play()
            }
        }
        for child in node.childNodes {
            enableLoopingAnimations(in: child)
        }
    }

    private static func setupLighting(in scene: SCNScene) {
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .spot
        key.light?.intensity = 520
        key.light?.color = NSColor(srgbRed: 1.0, green: 0.96, blue: 0.91, alpha: 1)
        key.light?.spotInnerAngle = 35
        key.light?.spotOuterAngle = 72
        key.light?.castsShadow = true
        key.light?.shadowMode = .deferred
        key.light?.shadowRadius = 7.0
        key.light?.shadowSampleCount = 16
        key.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
        key.light?.shadowColor = NSColor(srgbRed: 0.05, green: 0.08, blue: 0.16, alpha: 0.26)
        key.position = SCNVector3(2.8, 4.2, 3.6)
        key.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 180
        fill.light?.color = NSColor(srgbRed: 0.78, green: 0.88, blue: 1.0, alpha: 1)
        fill.eulerAngles = SCNVector3(-0.35, -0.95, 0)
        scene.rootNode.addChildNode(fill)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 220
        rim.light?.color = NSColor(srgbRed: 0.92, green: 0.96, blue: 1.0, alpha: 1)
        rim.eulerAngles = SCNVector3(0.45, -2.55, 0)
        scene.rootNode.addChildNode(rim)
    }

    private static func setupCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        let cam = SCNCamera()
        cam.fieldOfView = 32
        cam.wantsHDR = false
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 1.35, 4.75)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }
}
