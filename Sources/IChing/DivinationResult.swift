import Foundation

struct DivinationQuote: Hashable {
    /// 「《泰》卦辞」「《乾》九三」
    let title: String
    let text: String
    /// 主辞（取辞规则指定的那一句）为 true，辅辞为 false。
    let isPrimary: Bool
}

/// 一条高岛断语：卦断或某爻的爻断。
struct TakashimaEntry: Hashable, Identifiable {
    let title: String
    let text: String

    var id: String { title }
}

struct DivinationResult: Hashable, Identifiable {
    let question: String
    /// 自下而上六爻
    let lines: [CoinLine]
    let primary: Hexagram
    let changed: Hexagram?
    /// 变爻爻位，1 为初爻
    let changingPositions: [Int]
    let quotes: [DivinationQuote]
    /// 取辞依据，如「一爻变，按《高岛易断》主看本卦动爻爻断与爻辞」
    let quoteRule: String
    /// 按所问事项切题摘出的《高岛易断》核心断语（动爻爻断 → 本卦卦断 → 之卦卦断）
    let takashimaHighlights: [TakashimaHighlight]
    let verdict: Verdict
    let reasons: [String]
    let createdAt: Date

    var id: String { "\(createdAt.timeIntervalSince1970)-\(primary.number)" }

    var changingDescription: String? {
        guard !changingPositions.isEmpty else { return nil }
        return changingPositions.map(Self.positionName).joined(separator: "、") + "动"
    }

    /// 高岛易断：本卦卦断 + 各动爻爻断 + 之卦卦断。
    var takashimaEntries: [TakashimaEntry] {
        var entries: [TakashimaEntry] = []
        if !primary.takashimaGeneral.isEmpty {
            entries.append(TakashimaEntry(title: "《\(primary.name)》卦断", text: primary.takashimaGeneral))
        }
        for position in changingPositions {
            guard
                let line = primary.line(at: position),
                let text = primary.takashimaLine(at: position)
            else { continue }
            entries.append(TakashimaEntry(title: "《\(primary.name)》\(line.name) 爻断", text: text))
        }
        if let changed, changed.number != primary.number, !changed.takashimaGeneral.isEmpty {
            entries.append(TakashimaEntry(title: "《\(changed.name)》卦断", text: changed.takashimaGeneral))
        }
        return entries
    }

    /// 1...6 → 初/二/三/四/五/上
    static func positionName(_ index: Int) -> String {
        switch index {
        case 1: return "初爻"
        case 6: return "上爻"
        default: return "\(["", "二", "三", "四", "五"][index - 1])爻"
        }
    }
}