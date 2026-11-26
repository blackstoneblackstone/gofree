import SwiftUI

struct Verdict: Hashable {
    enum Level: String {
        case go = "可行"
        case cautious = "审慎"
        case avoid = "不宜"

        var color: Color {
            switch self {
            case .go: return Theme.jieqi
            case .cautious: return Theme.earnings
            case .avoid: return Theme.festival
            }
        }
    }

    let level: Level
    /// -1...1
    let score: Double
    /// 一句话结论
    let summary: String

    var color: Color { level.color }

    /// 可行 / 审慎 / 不宜 的统一门槛，结论与文案都从这里取。
    static func level(for score: Double) -> Level {
        if score >= 0.4 { return .go }
        if score <= -0.4 { return .avoid }
        return .cautious
    }

    static func make(score: Double, summary: String) -> Verdict {
        Verdict(level: level(for: score), score: score, summary: summary)
    }
}