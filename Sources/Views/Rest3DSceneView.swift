import AppKit
import SceneKit
import SwiftUI

/// Blender 5.3 导出的真 3D（.usdz）动作演示舞台：
/// 带程序化影棚柔光箱环境贴图、HDR Bloom、软投影、自动居中构图，并支持鼠标拖拽自由旋转查看。
struct Rest3DSceneView: View {
    let activity: RestActivity
    var height: CGFloat = 188

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RadialGradient(
                    colors: [
                        activity.category.tint.opacity(0.18),
                        activity.category.tint.opacity(0.04),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.48),
                    startRadius: 8,
                    endRadius: height * 0.95
                )

                // SceneKit 加载 Blender .usdz 高模 + 关键帧动画
                RestUSDZViewRepresentable(activityID: activity.id)
            }
            .frame(height: max(120, height - 30))

            // 底部独立动作要领条（不与 3D 画面重叠）
            HStack(spacing: 5) {
                Image(systemName: activity.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(activity.category.tint)
                Text(activity.visualCue)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(Theme.cardSolid.opacity(0.62))
            .overlay(alignment: .top) {
                Hairline()
            }
        }
        .background(Theme.divineInset)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(activity.category.tint.opacity(0.22), lineWidth: 0.8)
        }
    }
}

// MARK: - SceneKit USDZ Loader

private struct RestUSDZViewRepresentable: NSViewRepresentable {
    let activityID: String

    final class Coordinator {
        var currentActivityID: String = ""
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
        context.coordinator.currentActivityID = activityID
        view.scene = RestUSDZSceneLoader.loadScene(for: activityID)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        guard context.coordinator.currentActivityID != activityID else { return }
        context.coordinator.currentActivityID = activityID
        nsView.scene = RestUSDZSceneLoader.loadScene(for: activityID)
        nsView.isPlaying = true
    }
}

private enum RestUSDZSceneLoader {

    /// 程序化影棚环境贴图：让 Blender 导出的陶瓷、阳极铝、玻璃、水柱表面自然呈现柔光箱反射
    private static let studioEnvironmentImage: NSImage = {
        let size = NSSize(width: 256, height: 128)
        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            let colors = [
                NSColor(srgbRed: 0.16, green: 0.20, blue: 0.28, alpha: 1).cgColor,
                NSColor(srgbRed: 0.66, green: 0.76, blue: 0.90, alpha: 1).cgColor,
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
            let softbox = NSColor(white: 1.0, alpha: 0.95).cgColor
            let clear = NSColor(white: 1.0, alpha: 0.0).cgColor
            if let radial = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [softbox, clear] as CFArray, locations: [0, 1]) {
                ctx.drawRadialGradient(
                    radial,
                    startCenter: CGPoint(x: 70, y: 94),
                    startRadius: 4,
                    endCenter: CGPoint(x: 70, y: 94),
                    endRadius: 52,
                    options: []
                )
                ctx.drawRadialGradient(
                    radial,
                    startCenter: CGPoint(x: 196, y: 84),
                    startRadius: 4,
                    endCenter: CGPoint(x: 196, y: 84),
                    endRadius: 40,
                    options: []
                )
            }
        }
        image.unlockFocus()
        return image
    }()

    static func loadScene(for activityID: String) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        scene.lightingEnvironment.contents = studioEnvironmentImage
        scene.lightingEnvironment.intensity = 0.36

        let stage = SCNNode()
        scene.rootNode.addChildNode(stage)

        // 加载 Blender 导出的 .usdz（同时兼容 RestModels 子目录与扁平资源路径）
        let url = Bundle.main.url(forResource: activityID, withExtension: "usdz", subdirectory: "RestModels")
            ?? Bundle.main.url(forResource: activityID, withExtension: "usdz")

        if let url, let loaded = try? SCNScene(url: url, options: [
            .checkConsistency: false,
            .flattenScene: false
        ]) {
            let modelRoot = SCNNode()
            for child in loaded.rootNode.childNodes {
                modelRoot.addChildNode(child)
            }

            // 递归保证 Blender 导出的关键帧动画无限循环播放
            enableLoopingAnimations(in: modelRoot)

            // 自动按包围盒居中并归一化尺寸，确保任何模型都完整构图、不裁切
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
            let fitScale = CGFloat(2.55 / maxDim)
            modelRoot.scale = SCNVector3(fitScale, fitScale, fitScale)
            modelRoot.position = SCNVector3(
                -center.x * fitScale,
                -center.y * fitScale,
                -center.z * fitScale
            )

            stage.addChildNode(modelRoot)
        }

        // 轻微展示台摆动 + 弹性入场
        stage.scale = SCNVector3(0.88, 0.88, 0.88)
        let popIn = SCNAction.scale(to: 1.0, duration: 0.34)
        popIn.timingMode = .easeOut
        stage.runAction(popIn)

        let swayLeft = SCNAction.rotateTo(x: 0.02, y: -0.22, z: 0, duration: 4.0)
        swayLeft.timingMode = .easeInEaseOut
        let swayRight = SCNAction.rotateTo(x: -0.02, y: 0.22, z: 0, duration: 4.0)
        swayRight.timingMode = .easeInEaseOut
        stage.runAction(.repeatForever(.sequence([swayLeft, swayRight])))

        setupStudioLighting(in: scene)
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

    private static func setupStudioLighting(in scene: SCNScene) {
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
        key.light?.shadowColor = NSColor(srgbRed: 0.05, green: 0.08, blue: 0.16, alpha: 0.28)
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
        cameraNode.look(at: SCNVector3(0, 0.0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }
}
