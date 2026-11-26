import Foundation

/// 应用数据目录：`~/Library/Application Support/gofree`。
/// 设了 `GOFREE_STORAGE_DIR` 就指到别处——截图、自检、临时验证用它，
/// 免得测试跑到用户真实的数据和 Key 上。
enum AppPaths {

    static var supportDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["GOFREE_STORAGE_DIR"], !override.isEmpty {
            let dir = URL(fileURLWithPath: override, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("gofree", isDirectory: true)
    }

    /// 取子目录，不存在就建
    static func directory(_ name: String) -> URL {
        let dir = supportDirectory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
