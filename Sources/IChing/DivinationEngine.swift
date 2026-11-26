import Foundation

/// 起卦与断卦。
///
/// 默认用《高岛易断》所用的略筮法（三变筮法：四十九策分二挂一，三变定下卦、上卦与一动爻），
/// 也支持三枚铜钱与大衍之数（十八变）。
/// 断卦以《高岛易断》切题断语为主，参以《周易》卦爻辞原文与朱熹《易学启蒙》取辞法。
@MainActor
enum DivinationEngine {
    // MARK: 起卦

    static func cast<G: RandomNumberGenerator>(using generator: inout G) -> [CoinLine] {
        (0..<6).map { _ in
            var backs = 0
            for _ in 0..<3 where Bool.random(using: &generator) {
                backs += 1
            }
            return CoinLine(value: value(backs: backs))
        }
    }

    /// 大衍之数：五十策，其用四十九。分二、挂一、揲四、归奇为一变，三变成一爻，十八变成一卦。
    /// 一次「变」剩下的策数必为四的倍数：四十九策去五或去九，得 44 或 40。
    static func yarrowChange<G: RandomNumberGenerator>(_ count: Int, using generator: inout G) -> Int {
        // 分二：左堆至少一策，右堆留够「挂一」与「揲四」
        let left = Int.random(in: 1..<(count - 2), using: &generator)
        let right = count - left
        let hanging = 1
        let leftRemainder = remainderOfFour(left)
        let rightRemainder = remainderOfFour(right - hanging)
        return count - hanging - leftRemainder - rightRemainder
    }

    /// 揲四：以四为单位数，余零按四算。
    private static func remainderOfFour(_ count: Int) -> Int {
        let rest = count % 4
        return rest == 0 ? 4 : rest
    }

    /// 某一爻在三次变之后各自的剩余策数，只用于起卦过程展示。
    ///
    /// 真实演算是随机的（分二位置不同），这里按结果反推一条合法路径：
    /// 三变各去掉 5/9 与 4/8 与 4/8，剩下的策数除以四就是爻值。
    static func yarrowCounts(for value: Int) -> [Int] {
        let removals: [Int]
        switch value {
        case 9: removals = [5, 4, 4]
        case 8: removals = [9, 4, 4]
        case 7: removals = [5, 8, 8]
        case 6: removals = [9, 8, 8]
        default: removals = []
        }
        var stalks = 49
        return removals.map { removal in
            stalks -= removal
            return stalks
        }
    }

    /// 大衍筮法的一爻，结果必为 6/7/9/8。
    static func yarrowValue<G: RandomNumberGenerator>(using generator: inout G) -> Int {
        var stalks = 49
        for _ in 0..<3 {
            stalks = yarrowChange(stalks, using: &generator)
        }
        return stalks / 4
    }

    /// 《高岛易断》略筮法（三变筮法）：
    /// 五十策去一用四十九；第一变分二挂一、以八除之定下卦（先天八卦：乾1兑2离3震4巽5坎6艮7坤8），
    /// 第二变以八除之定上卦，第三变以六除之定一动爻。必出一动爻，与《高岛易断》六爻断语一一对应。
    static func takashimaCast<G: RandomNumberGenerator>(using generator: inout G) -> [CoinLine] {
        // 四十九策分二，左手取 1...48 策（右手至少留 1 策挂于小指），48 为 8 与 6 的公倍数，各卦各爻均等。
        func remainder(mod divisor: Int) -> Int {
            let left = Int.random(in: 1...48, using: &generator)
            let rem = left % divisor
            return rem == 0 ? divisor : rem
        }
        let trigrams = Trigram.allCases
        let lower = trigrams[remainder(mod: 8) - 1]
        let upper = trigrams[remainder(mod: 8) - 1]
        let movingIndex = remainder(mod: 6) - 1
        let bits = lower.bits + upper.bits
        return bits.enumerated().map { index, isYang in
            let isMoving = index == movingIndex
            let value = isMoving ? (isYang ? 9 : 6) : (isYang ? 7 : 8)
            return CoinLine(value: value)
        }
    }

    static func cast<G: RandomNumberGenerator>(method: DivinationMethod, using generator: inout G) -> [CoinLine] {
        switch method {
        case .takashima:
            return takashimaCast(using: &generator)
        case .coins:
            return cast(using: &generator)
        case .yarrow:
            return (0..<6).map { _ in CoinLine(value: yarrowValue(using: &generator)) }
        }
    }

    static func cast(method: DivinationMethod, seed: UInt64?) -> [CoinLine] {
        if let seed {
            var generator = SeededGenerator(seed: seed)
            return cast(method: method, using: &generator)
        }
        var generator = SystemRandomNumberGenerator()
        return cast(method: method, using: &generator)
    }

    static func cast(seed: UInt64?) -> [CoinLine] {
        if let seed {
            var generator = SeededGenerator(seed: seed)
            return cast(using: &generator)
        }
        var generator = SystemRandomNumberGenerator()
        return cast(using: &generator)
    }

    /// 背影（阳面）枚数 → 爻值。
    static func value(backs: Int) -> Int {
        switch backs {
        case 0: return 6
        case 1: return 7
        case 2: return 8
        default: return 9
        }
    }

    static func cast(values: [Int]) -> [CoinLine] {
        values.map(CoinLine.init(value:))
    }

    // MARK: 断卦

    static func judge(
        question: String,
        lines: [CoinLine],
        now: Date = Date()
    ) -> DivinationResult? {
        HexagramTable.prepare()
        guard lines.count == 6 else { return nil }
        let primaryBits = lines.map(\.isYang)
        guard let primary = HexagramTable.hexagram(bits: primaryBits) else { return nil }

        let positions = lines.enumerated()
            .filter { $0.element.isChanging }
            .map { $0.offset + 1 }

        let changed: Hexagram? = positions.isEmpty
            ? nil
            : HexagramTable.hexagram(bits: lines.map { $0.isChanging ? !$0.isYang : $0.isYang })

        let (quotes, rule) = quotes(for: primary, changed: changed, positions: positions)
        let highlights = Takashima.highlights(
            question: question,
            primary: primary,
            changed: changed,
            changingPositions: positions
        )

        let (takashimaScore, takashimaHits) = Takashima.score(highlights: highlights)
        let lexScore = Lexicon.normalized(quotes)
        let total: Double = takashimaHits.isEmpty
            ? lexScore
            : max(-1, min(1, 0.65 * takashimaScore + 0.35 * lexScore))

        var reasons: [String] = [rule]
        reasons.append(takashimaReason(highlights: highlights, score: takashimaScore, hits: takashimaHits))
        reasons.append(lexiconReason(for: quotes, score: lexScore))
        reasons.append(movementReason(positions: positions, changed: changed))

        return DivinationResult(
            question: question,
            lines: lines,
            primary: primary,
            changed: changed,
            changingPositions: positions,
            quotes: quotes,
            quoteRule: rule,
            takashimaHighlights: highlights,
            verdict: Verdict.make(
                score: total,
                summary: summary(
                    level: Verdict.level(for: total),
                    takashimaScore: takashimaScore,
                    hasTakashimaHits: !takashimaHits.isEmpty,
                    lexScore: lexScore
                )
            ),
            reasons: reasons,
            createdAt: now
        )
    }

    // MARK: 取辞（朱熹《易学启蒙》）

    private static func quotes(
        for primary: Hexagram,
        changed: Hexagram?,
        positions: [Int]
    ) -> ([DivinationQuote], String) {
        func lineQuote(_ hexagram: Hexagram, _ index: Int, primary isPrimary: Bool) -> DivinationQuote? {
            guard let line = hexagram.line(at: index) else { return nil }
            return DivinationQuote(
                title: "《\(hexagram.name)》\(line.name)",
                text: line.text,
                isPrimary: isPrimary
            )
        }
        func judgment(_ hexagram: Hexagram, primary isPrimary: Bool) -> DivinationQuote {
            DivinationQuote(
                title: "《\(hexagram.name)》卦辞",
                text: hexagram.judgment,
                isPrimary: isPrimary
            )
        }

        switch positions.count {
        case 0:
            return ([judgment(primary, primary: true)], "六爻皆静，看本卦卦辞")

        case 1:
            guard let quote = lineQuote(primary, positions[0], primary: true) else {
                return ([judgment(primary, primary: true)], "一爻变，按《高岛易断》主看本卦动爻爻断与爻辞")
            }
            return ([quote], "一爻变，按《高岛易断》主看\(quote.title)爻断与爻辞")

        case 2:
            let upper = max(positions[0], positions[1])
            let lower = min(positions[0], positions[1])
            var list: [DivinationQuote] = []
            if let main = lineQuote(primary, upper, primary: true) { list.append(main) }
            if let second = lineQuote(primary, lower, primary: false) { list.append(second) }
            return (list, "二爻变，取本卦两变爻爻辞，以上爻为主")

        case 3:
            var list = [judgment(primary, primary: true)]
            if let changed { list.append(judgment(changed, primary: false)) }
            return (list, "三爻变，本卦与变卦卦辞并看，以本卦为主")

        case 4:
            guard let changed else { return ([judgment(primary, primary: true)], "四爻变") }
            let still = (1...6).filter { !positions.contains($0) }
            var list: [DivinationQuote] = []
            if let main = lineQuote(changed, still.min() ?? 1, primary: true) { list.append(main) }
            if let second = lineQuote(changed, still.max() ?? 1, primary: false) { list.append(second) }
            return (list, "四爻变，取变卦中两个不变爻的爻辞，以下爻为主")

        case 5:
            guard let changed else { return ([judgment(primary, primary: true)], "五爻变") }
            let still = (1...6).first { !positions.contains($0) } ?? 1
            let list = lineQuote(changed, still, primary: true).map { [$0] } ?? []
            return (list, "五爻变，取变卦中不变爻的爻辞")

        default:
            if primary.number == 1, let extra = primary.extra {
                return (
                    [DivinationQuote(title: "《乾》\(extra.name)", text: extra.text, isPrimary: true)],
                    "六爻皆变，乾卦用九"
                )
            }
            if primary.number == 2, let extra = primary.extra {
                return (
                    [DivinationQuote(title: "《坤》\(extra.name)", text: extra.text, isPrimary: true)],
                    "六爻皆变，坤卦用六"
                )
            }
            guard let changed else { return ([judgment(primary, primary: true)], "六爻皆变") }
            return ([judgment(changed, primary: true)], "六爻皆变，取变卦卦辞")
        }
    }

    // MARK: 文案

    private static func takashimaReason(
        highlights: [TakashimaHighlight],
        score: Double,
        hits: [(String, Int)]
    ) -> String {
        let primaryTopic = highlights.first(where: \.isPrimary)?.topic ?? highlights.first?.topic
        let label = primaryTopic.map { "高岛断语（\($0)）" } ?? "高岛断语"
        guard !hits.isEmpty else {
            return "\(label)未见明言吉凶，须按断语实情审度"
        }
        let listed = hits.prefix(3).map { "\($0.0)×\($0.1)" }.joined(separator: "、")
        let tone = score > 0.2 ? "断意偏吉" : (score < -0.2 ? "断意告诫" : "断意审慎")
        return "\(label)见 \(listed)，\(tone)"
    }

    private static func lexiconReason(for quotes: [DivinationQuote], score: Double) -> String {
        let hits = Lexicon.hits(quotes)
        guard !hits.isEmpty else {
            return "《周易》原文未见吉凶断词，事在两可之间"
        }
        let listed = hits.prefix(3).map { "\($0.0)×\($0.1)" }.joined(separator: "、")
        let tone = score > 0.2 ? "辞意偏吉" : (score < -0.2 ? "辞意偏凶" : "辞意两可")
        return "《周易》原文见 \(listed)，\(tone)"
    }

    private static func movementReason(positions: [Int], changed: Hexagram?) -> String {
        if positions.isEmpty {
            return "六爻不动，局势已定，看本卦卦断"
        }
        let moved = positions.count
        let target = changed.map { "之卦《\($0.name)》，事态向此走" } ?? "无变卦"
        let count = DivinationResult.positionName(moved).replacingOccurrences(of: "爻", with: "")
        if moved >= 4 {
            return "\(count)爻动，局面大变，\(target)"
        }
        if moved >= 2 {
            return "\(count)爻动，事有反复，\(target)"
        }
        return "一爻动，\(target)"
    }

    private static func summary(
        level: Verdict.Level,
        takashimaScore: Double,
        hasTakashimaHits: Bool,
        lexScore: Double
    ) -> String {
        let takashimaTone: String = {
            guard hasTakashimaHits else { return "高岛断语须细参原文" }
            if takashimaScore > 0.2 { return "高岛断意偏吉" }
            if takashimaScore < -0.2 { return "高岛断意告诫" }
            return "高岛断意审慎"
        }()
        let lexTone = lexScore > 0.2 ? "辞意偏吉" : (lexScore < -0.2 ? "辞意告诫" : "辞意两可")
        switch level {
        case .go:
            return "可做。\(takashimaTone)，\(lexTone)。"
        case .avoid:
            return "不宜。\(takashimaTone)，\(lexTone)。"
        case .cautious:
            return "可做但要留退路。\(takashimaTone)，\(lexTone)。"
        }
    }
}

// MARK: - 吉凶词

private enum Lexicon {
    /// 长的写在前面，避免「无不利」被「不利」拆走。
    static let words: [(String, Double)] = [
        ("无不利", 2.0),
        ("无攸利", -1.8),
        ("贞凶", -2.4),
        ("大吉", 2.6),
        ("元吉", 2.6),
        ("无咎", 0.5),
        ("悔亡", 1.0),
        ("不利", -1.8),
        ("吉", 1.8),
        ("亨", 0.3),
        ("利", 0.4),
        ("吝", -0.9),
        ("厉", -1.0),
        ("悔", -0.8),
        ("凶", -2.6)
    ]

    static func hits(_ quotes: [DivinationQuote]) -> [(String, Int)] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for quote in quotes {
            var text = quote.text
            for (word, _) in words {
                while let range = text.range(of: word) {
                    if counts[word] == nil { order.append(word) }
                    counts[word, default: 0] += 1
                    text.removeSubrange(range)
                }
            }
        }
        return order.compactMap { word in counts[word].map { (word, $0) } }
    }

    static func normalized(_ quotes: [DivinationQuote]) -> Double {
        var total = 0.0
        var occurrences = 0
        for quote in quotes {
            let weight = quote.isPrimary ? 1.0 : 0.5
            var text = quote.text
            for (word, value) in words {
                while let range = text.range(of: word) {
                    total += value * weight
                    occurrences += 1
                    text.removeSubrange(range)
                }
            }
        }
        guard occurrences > 0 else { return 0 }
        return max(-1, min(1, total / 3.2))
    }
}

// MARK: - 可复现随机数

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}