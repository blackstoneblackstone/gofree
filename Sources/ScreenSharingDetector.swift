import AppKit
import CoreGraphics
import Foundation

/// 检测当前是否正在投屏、镜像外接显示器、共享屏幕或全屏演示。
/// 全部采用无需录屏权限的系统信号（Display 状态 + 公开窗口元信息）。
enum ScreenSharingDetector {

    struct Status: Equatable {
        let isCasting: Bool
        let reason: String?

        static let idle = Status(isCasting: false, reason: nil)
    }

    static func currentStatus() -> Status {
        // 1. 屏幕镜像（AirPlay 镜像 / 投影仪镜像 / 会议室投屏）
        if isAnyDisplayMirrored() {
            return Status(isCasting: true, reason: "屏幕镜像投屏中")
        }

        // 2. AirPlay / 无线投屏扩展屏
        if hasAirPlayOrWirelessDisplay() {
            return Status(isCasting: true, reason: "AirPlay 投屏中")
        }

        // 3. 系统共享屏幕 / 会议软件共享屏幕浮条 / 全屏演示
        if let reason = detectActiveSharingOrPresentationWindow() {
            return Status(isCasting: true, reason: reason)
        }

        return .idle
    }

    /// 检查是否有显示器处于镜像集合中
    private static func isAnyDisplayMirrored() -> Bool {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return false
        }
        var displays = Array<CGDirectDisplayID>(repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else {
            return false
        }
        return displays.prefix(Int(displayCount)).contains { CGDisplayIsInMirrorSet($0) != 0 }
    }

    /// 检查是否连着 AirPlay / 无线投屏显示器
    private static func hasAirPlayOrWirelessDisplay() -> Bool {
        for screen in NSScreen.screens {
            let name = screen.localizedName.lowercased()
            if name.contains("airplay") || name.contains("apple tv") || name.contains("wireless") || name.contains("投屏") {
                return true
            }
        }
        return false
    }

    /// 检查在屏窗口列表中是否存在共享屏幕浮条、录屏指示器或全屏演示窗口
    private static func detectActiveSharingOrPresentationWindow() -> String? {
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let sharingOwners: Set<String> = [
            "screensharingagent",
            "screensharingd",
            "airplayuiagent"
        ]

        let meetingOwners: [String] = [
            "zoom.us",
            "tencentmeeting",
            "wemeet",
            "lark",
            "feishu",
            "飞书",
            "腾讯会议",
            "钉钉",
            "dingtalk",
            "microsoft teams",
            "teams",
            "webex",
            "wechat",
            "微信"
        ]

        let shareKeywords: [String] = [
            "sharing",
            "screen share",
            "you are screen sharing",
            "共享屏幕",
            "正在共享",
            "屏幕共享",
            "停止共享",
            "投屏"
        ]

        let presentationOwners: Set<String> = [
            "keynote",
            "microsoft powerpoint",
            "powerpoint"
        ]

        let screenBounds = NSScreen.main?.frame ?? .zero

        for entry in infoList {
            let owner = (entry[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            let title = (entry[kCGWindowName as String] as? String ?? "").lowercased()
            let layer = entry[kCGWindowLayer as String] as? Int ?? 0

            // 系统级屏幕共享 / AirPlay 代理有可见窗口
            if sharingOwners.contains(owner) {
                return "系统投屏/共享中"
            }

            // 会议软件的共享屏幕悬浮条（通常在较高层级，或标题含共享字样）
            if meetingOwners.contains(where: { owner.contains($0) }) {
                if shareKeywords.contains(where: { title.contains($0) }) {
                    return "会议共享屏幕中"
                }
            }

            // Keynote / PowerPoint 全屏放映
            if presentationOwners.contains(owner), layer >= 0,
               let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
               let w = boundsDict["Width"] as? CGFloat,
               let h = boundsDict["Height"] as? CGFloat,
               screenBounds.width > 0,
               w >= screenBounds.width - 2,
               h >= screenBounds.height - 2,
               (title.contains("slideshow") || title.contains("放映") || title.contains("演示") || layer > 0) {
                return "演示放映中"
            }
        }

        return nil
    }
}
