import Foundation

/// 通用的 OpenAI 兼容模型客户端：只管把 system + user 两条消息发出去，把回答取回来。
/// 配置来自配置中心（Base URL / 模型名 / 钥匙串里的 Key），解卦只是它的第一个使用者。
@MainActor
enum LLMClient {

    enum Failure: Error {
        case badURL
        case notConfigured
        case status(Int, String)
        case empty

        var message: String {
            switch self {
            case .badURL:
                return "Base URL 格式不对，应该像 https://api.openai.com/v1"
            case .notConfigured:
                return "还没配好大模型：到设置里的「大模型」填 Base URL、模型名和 API Key。"
            case let .status(code, body):
                let hint: String
                switch code {
                case 401, 403: hint = "API Key 不对或没权限"
                case 404: hint = "地址或模型名不对"
                case 429: hint = "请求太频繁或额度用完了"
                default: hint = "服务返回错误"
                }
                let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = trimmed.isEmpty ? "" : "：\(trimmed.prefix(200))"
                return "\(hint)（HTTP \(code)）\(detail)"
            case .empty:
                return "模型没有返回内容"
            }
        }
    }

    /// 开关打开且三样都齐了才谈得上「可以调用」
    static var isConfigured: Bool {
        let settings = AppSettings.shared
        return settings.llmEnabled
            && !settings.llmBaseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !settings.llmModel.trimmingCharacters(in: .whitespaces).isEmpty
            && !SecretStore.readAPIKey().isEmpty
    }

    static func endpoint(for baseURL: String) -> URL? {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: base + "/chat/completions")
    }

    /// 发一轮对话。调用方自己决定 system / user 怎么写。
    static func chat(
        system: String?,
        user: String,
        maxTokens: Int = 900,
        temperature: Double = 0.7
    ) async throws -> String {
        guard isConfigured else { throw Failure.notConfigured }
        guard let endpoint = endpoint(for: AppSettings.shared.llmBaseURL) else { throw Failure.badURL }

        var messages: [[String: String]] = []
        if let system, !system.isEmpty {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": user])

        let payload: [String: Any] = [
            "model": AppSettings.shared.llmModel,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false
        ]

        // OpenAI 的推理系模型（o 系 / gpt-5 系）只认 max_completion_tokens，不认 max_tokens，
        // 也不认非默认 temperature。遇到这种 400 就换参数再试一次，别的服务不受影响。
        do {
            return try await perform(endpoint: endpoint, payload: payload)
        } catch let Failure.status(400, body) where needsCompatPayload(body) {
            var compat = payload
            compat.removeValue(forKey: "temperature")
            compat.removeValue(forKey: "max_tokens")
            compat["max_completion_tokens"] = maxTokens
            return try await perform(endpoint: endpoint, payload: compat)
        }
    }

    private static func needsCompatPayload(_ body: String) -> Bool {
        let lowered = body.lowercased()
        return lowered.contains("max_completion_tokens")
            || (lowered.contains("unsupported parameter") && lowered.contains("temperature"))
    }

    private static func perform(endpoint: URL, payload: [String: Any]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SecretStore.readAPIKey())", forHTTPHeaderField: "Authorization")
        request.setValue("gofree/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw Failure.status(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = object["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw Failure.empty }

        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Failure.empty }
        return text
    }
}
