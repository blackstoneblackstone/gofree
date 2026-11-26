import Foundation

/// API Key 存在本机的一个独立文件里，不用钥匙串、也不和普通设置混在一起：
/// `~/Library/Application Support/gofree/secrets.json`，文件权限 0600（只有本人能读）。
/// 注意：这是**明文**存储。它只防同机其他用户，不防本人账户下的其他程序。
enum SecretStore {

    private static let fileName = "secrets.json"

    static var fileURL: URL { AppPaths.supportDirectory.appendingPathComponent(fileName) }

    static func readAPIKey() -> String {
        // 命令行验证时直接用环境变量喂 Key，绝不落盘
        if let inline = ProcessInfo.processInfo.environment["GOFREE_LLM_KEY"], !inline.isEmpty {
            return inline
        }
        guard
            let data = try? Data(contentsOf: fileURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: String],
            let key = object["llmAPIKey"]
        else { return "" }
        return key
    }

    static func writeAPIKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var object: [String: String] = [:]
        if let data = try? Data(contentsOf: fileURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            object = existing
        }
        if trimmed.isEmpty {
            object.removeValue(forKey: "llmAPIKey")
        } else {
            object["llmAPIKey"] = trimmed
        }

        let url = fileURL
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    static func deleteAPIKey() {
        writeAPIKey("")
    }
}
