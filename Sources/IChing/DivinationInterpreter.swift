import Foundation
import Observation

/// 一次解卦的解读状态：负责发请求、取消、持有结果文本。
@MainActor
@Observable
final class DivinationInterpreter {

    enum Phase: Equatable {
        case idle
        case loading
        case done(String)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// AI 解卦给出的定性结论（可行 / 审慎 / 不宜），用于与左栏结论印鉴保持一致。
    private(set) var interpretedLevel: Verdict.Level?

    init(previewText: String? = nil, previewFailure: String? = nil) {
        if let previewText {
            let parsed = Self.parse(previewText)
            interpretedLevel = parsed.level
            phase = .done(parsed.body)
        }
        if let previewFailure { phase = .failed(previewFailure) }
    }

    @ObservationIgnored private var task: Task<Void, Never>?

    /// 截图用：直接塞一段文本，不发请求
    func injectPreviewText(_ text: String) {
        cancel()
        let parsed = Self.parse(text)
        interpretedLevel = parsed.level
        phase = .done(parsed.body)
    }

    /// 截图用：直接塞一个失败态
    func injectPreviewFailure(_ message: String) {
        cancel()
        interpretedLevel = nil
        phase = .failed(message)
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    /// 切换卦象或重新起卦时清空上一次的解读，避免把上一问的回答留在新卦上。
    func reset() {
        cancel()
        interpretedLevel = nil
        phase = .idle
    }

    func interpret(_ result: DivinationResult) {
        guard LLMClient.isConfigured else {
            interpretedLevel = nil
            phase = .failed(LLMClient.Failure.notConfigured.message)
            return
        }
        cancel()
        interpretedLevel = nil
        phase = .loading
        let (system, user) = DivinationPrompt.make(for: result)

        task = Task { @MainActor in
            do {
                let text = try await LLMClient.chat(system: system, user: user)
                if Task.isCancelled { return }
                let parsed = Self.parse(text)
                interpretedLevel = parsed.level
                phase = .done(parsed.body)
            } catch is CancellationError {
                phase = .idle
            } catch {
                if Task.isCancelled { return }
                phase = .failed((error as? LLMClient.Failure)?.message ?? error.localizedDescription)
            }
        }
    }

    /// 拆出首行的「【结论】可行 / 审慎 / 不宜」标签，正文保持干净段落。
    static func parse(_ raw: String) -> (level: Verdict.Level?, body: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
        guard let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              first.hasPrefix("【结论】") || first.hasPrefix("结论：") || first.hasPrefix("结论:") else {
            return (nil, trimmed)
        }

        let level: Verdict.Level?
        if first.contains("不宜") || first.contains("不可") {
            level = .avoid
        } else if first.contains("审慎") || first.contains("谨慎") || first.contains("暂缓") {
            level = .cautious
        } else if first.contains("可行") || first.contains("可做") {
            level = .go
        } else {
            level = nil
        }

        let rest = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (level, rest.isEmpty ? trimmed : rest)
    }
}
