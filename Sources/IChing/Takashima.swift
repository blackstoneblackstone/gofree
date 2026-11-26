import Foundation

/// 一条《高岛易断》的分类占断，例如「问营商：得主伙合志，货财汇萃之象。」
struct TakashimaTopicItem: Hashable, Identifiable {
    let topic: String
    let text: String

    var id: String { "\(topic)-\(text.prefix(16))" }
}

/// 一段《高岛易断》原文拆解后的结构：
/// - `caseStudy`: 「断曰：…」占例与卦理分析（多见于爻断）
/// - `lead`: 【占】下不带「问X：」的总论（如《乾》卦断首句）
/// - `items`: 【占】下按「问时运 / 问营商 / 问功名…」分条的断语
struct TakashimaSection: Hashable {
    let caseStudy: String
    let lead: String
    let items: [TakashimaTopicItem]

    var isEmpty: Bool {
        caseStudy.isEmpty && lead.isEmpty && items.isEmpty
    }
}

/// 切题摘出的《高岛易断》核心断语，用于结果卡首屏展示、吉凶研判与 AI 提示词。
struct TakashimaHighlight: Hashable, Identifiable {
    /// 来源，例如「《泰》初九 爻断」「《泰》卦断」「《升》卦断」
    let source: String
    /// 对应门类，例如「问营商」「问时运」「总断」
    let topic: String
    /// 断语原文
    let text: String
    /// 是否为主断（动爻爻断；无动爻时为本卦卦断）
    let isPrimary: Bool

    var id: String { "\(source)-\(topic)-\(text.prefix(16))" }
}

/// 《高岛易断》的解析、切题匹配与吉凶研判。
enum Takashima {

    // MARK: 解析

    private static let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{3000}"))

    /// 把一条高岛原文（卦断或爻断）拆成「占例/断曰」「总论」与「分类占断」。
    static func parse(_ raw: String) -> TakashimaSection {
        let trimmed = raw.trimmingCharacters(in: trimSet)
        guard !trimmed.isEmpty else {
            return TakashimaSection(caseStudy: "", lead: "", items: [])
        }

        let caseStudy: String
        let zhanPart: String
        if let range = trimmed.range(of: "【占】") {
            caseStudy = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: trimSet)
            zhanPart = String(trimmed[range.upperBound...]).trimmingCharacters(in: trimSet)
        } else if trimmed.hasPrefix("断曰") {
            return TakashimaSection(caseStudy: trimmed, lead: "", items: [])
        } else {
            return TakashimaSection(caseStudy: "", lead: trimmed, items: [])
        }

        let segments = zhanPart
            .components(separatedBy: "○")
            .map { $0.trimmingCharacters(in: trimSet) }
            .filter { !$0.isEmpty }

        var leadParts: [String] = []
        var items: [TakashimaTopicItem] = []

        for segment in segments {
            if let (topic, body) = splitTopic(segment) {
                items.append(TakashimaTopicItem(topic: topic, text: body))
            } else {
                leadParts.append(segment)
            }
        }

        return TakashimaSection(
            caseStudy: caseStudy,
            lead: leadParts.joined(separator: " "),
            items: items
        )
    }

    /// 把「问营商：…」或「买卖：…」拆成门类与正文。
    private static func splitTopic(_ segment: String) -> (String, String)? {
        guard let colon = segment.firstIndex(where: { $0 == "：" || $0 == ":" }) else {
            return nil
        }
        let head = String(segment[..<colon]).trimmingCharacters(in: trimSet)
        let body = String(segment[segment.index(after: colon)...]).trimmingCharacters(in: trimSet)
        guard !head.isEmpty, head.count <= 10, !body.isEmpty else {
            return nil
        }
        return (head, body)
    }

    // MARK: 切题匹配

    private struct TopicRule {
        let keywords: [String]
        let topics: [String]
    }

    /// 现代日常问法 → 《高岛易断》原文中的门类名称（按常见度排序）。
    private static let topicRules: [TopicRule] = [
        TopicRule(
            keywords: ["仓", "股", "投资", "买", "卖", "生意", "项目", "合作", "单子", "钱", "价", "创业", "开张", "理财", "基金", "币", "盈", "亏", "签单", "业务", "副业", "公司", "经商", "行情", "涨", "跌"],
            topics: ["营商", "商业", "买卖", "谋事", "家业"]
        ),
        TopicRule(
            keywords: ["工作", "职位", "升", "面试", "考试", "考研", "考公", "学", "offer", "跳槽", "入职", "离职", "辞职", "转行", "晋升", "职称", "论文", "毕业", "申请", "留学", "仕", "官", "前程"],
            topics: ["功名", "仕途", "谋事"]
        ),
        TopicRule(
            keywords: ["房", "搬家", "住", "装修", "租", "买房", "卖房", "家", "宅", "迁居", "置业"],
            topics: ["家宅", "家业"]
        ),
        TopicRule(
            keywords: ["婚", "恋", "感情", "分手", "复合", "相亲", "表白", "结婚", "对象", "伴侣", "爱", "约会", "追"],
            topics: ["婚姻", "婚嫁", "嫁娶"]
        ),
        TopicRule(
            keywords: ["病", "医", "健康", "体检", "手术", "药", "治", "身体", "康复"],
            topics: ["疾病"]
        ),
        TopicRule(
            keywords: ["官司", "纠纷", "仲裁", "诉讼", "维权", "起诉", "合同", "赔", "法院"],
            topics: ["讼事"]
        ),
        TopicRule(
            keywords: ["出行", "旅", "出差", "签证", "远行", "回国", "机票", "出发", "行程"],
            topics: ["出行", "行人"]
        ),
        TopicRule(
            keywords: ["丢", "失", "找", "忘", "寻", "遗失"],
            topics: ["失物"]
        ),
        TopicRule(
            keywords: ["孕", "产", "生子", "生女", "宝宝", "备孕", "怀"],
            topics: ["六甲", "生产"]
        ),
        TopicRule(
            keywords: ["战", "竞", "比赛", "打", "争", "胜负", "对手", "抢"],
            topics: ["战征"]
        ),
    ]

    /// 识别问题命中的高岛门类标签（如 ["营商", "商业", ...]）。
    static func matchedTopicNames(for question: String) -> [String] {
        let lowered = question.lowercased()
        var names: [String] = []
        for rule in topicRules {
            if rule.keywords.contains(where: { lowered.contains($0) }) {
                for topic in rule.topics where !names.contains(topic) {
                    names.append(topic)
                }
            }
        }
        return names
    }

    /// 从一段解析后的高岛原文中，挑出最切题的 1–2 条分类占断。
    static func matchItems(in section: TakashimaSection, for question: String, limit: Int = 2) -> [TakashimaTopicItem] {
        let wanted = matchedTopicNames(for: question)
        var picked: [TakashimaTopicItem] = []

        if !wanted.isEmpty {
            for target in wanted {
                for item in section.items where matches(item.topic, target: target) {
                    if !picked.contains(item) {
                        picked.append(item)
                    }
                    if picked.count >= limit { return picked }
                }
            }
        }

        // 切题项不足时，补「问时运」或「问谋事」作总纲（但若已命中具体门类，最多补 1 条时运）
        let fallbacks = ["时运", "谋事", "国家气运"]
        for target in fallbacks where picked.count < limit {
            if let item = section.items.first(where: { matches($0.topic, target: target) }),
               !picked.contains(item) {
                picked.append(item)
            }
        }

        if picked.isEmpty, !section.lead.isEmpty {
            picked.append(TakashimaTopicItem(topic: "总断", text: section.lead))
        }
        if picked.isEmpty, let first = section.items.first {
            picked.append(first)
        }
        if picked.isEmpty, !section.caseStudy.isEmpty {
            let preview = section.caseStudy.count <= 160
                ? section.caseStudy
                : String(section.caseStudy.prefix(160)) + "…"
            picked.append(TakashimaTopicItem(topic: "断曰", text: preview))
        }

        return Array(picked.prefix(limit))
    }

    private static func matches(_ itemTopic: String, target: String) -> Bool {
        itemTopic == "问\(target)" || itemTopic == target || itemTopic.contains(target)
    }

    /// 供提示词或摘要使用的单段节选（兼容「问营商：…」格式）。
    static func excerpt(_ raw: String, for question: String, maxLength: Int = 420) -> String {
        let section = parse(raw)
        let items = matchItems(in: section, for: question, limit: 3)
        guard !items.isEmpty else {
            let trimmed = raw.trimmingCharacters(in: trimSet)
            return trimmed.count <= maxLength ? trimmed : String(trimmed.prefix(maxLength)) + "…"
        }
        let joined = items
            .map { $0.topic == "总断" || $0.topic == "断曰" ? $0.text : "\($0.topic)：\($0.text)" }
            .joined(separator: "；")
        return joined.count <= maxLength ? joined : String(joined.prefix(maxLength)) + "…"
    }

    /// 为一次占卦挑出最核心的高岛断语：
    /// 动爻爻断（主）→ 本卦卦断（无动爻为主，有动爻为参）→ 之卦卦断（趋向）。
    static func highlights(
        question: String,
        primary: Hexagram,
        changed: Hexagram?,
        changingPositions: [Int]
    ) -> [TakashimaHighlight] {
        var result: [TakashimaHighlight] = []

        // 1. 动爻爻断（高岛易断一爻变为主；多爻变时取前两动爻避免过长）
        for position in changingPositions.prefix(2) {
            guard
                let line = primary.line(at: position),
                let raw = primary.takashimaLine(at: position)
            else { continue }
            let section = parse(raw)
            let items = matchItems(in: section, for: question, limit: changingPositions.count == 1 ? 2 : 1)
            for item in items {
                result.append(TakashimaHighlight(
                    source: "《\(primary.name)》\(line.name) 爻断",
                    topic: item.topic,
                    text: item.text,
                    isPrimary: true
                ))
            }
        }

        // 2. 本卦卦断
        if !primary.takashimaGeneral.isEmpty {
            let section = parse(primary.takashimaGeneral)
            let items = matchItems(in: section, for: question, limit: changingPositions.isEmpty ? 2 : 1)
            for item in items {
                result.append(TakashimaHighlight(
                    source: "《\(primary.name)》卦断",
                    topic: item.topic,
                    text: item.text,
                    isPrimary: changingPositions.isEmpty
                ))
            }
        }

        // 3. 之卦卦断（事态趋向）
        if let changed, changed.number != primary.number, !changed.takashimaGeneral.isEmpty {
            let section = parse(changed.takashimaGeneral)
            let items = matchItems(in: section, for: question, limit: 1)
            for item in items {
                result.append(TakashimaHighlight(
                    source: "之卦《\(changed.name)》卦断",
                    topic: item.topic,
                    text: item.text,
                    isPrimary: false
                ))
            }
        }

        return result
    }

    // MARK: 高岛断语吉凶研判

    /// 《高岛易断》常用断语词表：长词在前，避免否定词被拆走。
    private static let lexicon: [(String, Double)] = [
        ("大失利", -2.6),
        ("无不利", 2.0),
        ("无攸利", -1.8),
        ("攻无不克", 2.4),
        ("满载而归", 2.2),
        ("进退两难", -1.8),
        ("得失不偿", -1.8),
        ("不利买", -1.4),
        ("不可遽信", -1.6),
        ("不可轻进", -1.4),
        ("未可遽信", -1.6),
        ("大吉", 2.6),
        ("元吉", 2.6),
        ("极吉", 2.6),
        ("大凶", -2.8),
        ("贞凶", -2.4),
        ("必败", -2.4),
        ("必成", 2.0),
        ("必得", 1.8),
        ("可必", 1.8),
        ("可成", 1.6),
        ("无忧", 1.5),
        ("无碍", 1.2),
        ("无咎", 0.5),
        ("悔亡", 1.0),
        ("获利", 1.8),
        ("利大", 1.8),
        ("大获", 2.0),
        ("吉兆", 2.0),
        ("亨通", 1.6),
        ("大通", 1.8),
        ("顺遂", 1.6),
        ("升迁", 1.6),
        ("丰登", 1.6),
        ("平安", 1.2),
        ("有喜", 1.4),
        ("得志", 1.4),
        ("谢绝", -1.8),
        ("失利", -2.0),
        ("不利", -1.8),
        ("不可", -1.4),
        ("不宜", -1.5),
        ("难成", -1.8),
        ("无成", -1.8),
        ("颠倒", -1.5),
        ("失当", -1.4),
        ("审慎", -0.8),
        ("须慎", -0.9),
        ("慎重", -0.8),
        ("谨慎", -0.8),
        ("防败", -1.2),
        ("覆辙", -1.6),
        ("鲁莽", -1.4),
        ("凶", -2.6),
        ("吉", 1.8),
        ("亨", 0.5),
        ("利", 0.5),
        ("吝", -1.0),
        ("厉", -1.1),
        ("悔", -0.8),
        ("败", -1.6),
        ("危", -1.4),
        ("阻", -1.0),
        ("灾", -1.8),
        ("祸", -1.8),
        ("忧", -0.8),
        ("惧", -0.8),
    ]

    /// 统计切题高岛断语里的吉凶倾向，返回 (-1...1 分数, 命中词列表)。
    static func score(highlights: [TakashimaHighlight]) -> (score: Double, hits: [(String, Int)]) {
        var total = 0.0
        var occurrences = 0
        var counts: [String: Int] = [:]
        var order: [String] = []

        for item in highlights {
            let weight = item.isPrimary ? 1.0 : 0.45
            var text = item.text
            for (word, value) in lexicon {
                while let range = text.range(of: word) {
                    total += value * weight
                    occurrences += 1
                    if counts[word] == nil { order.append(word) }
                    counts[word, default: 0] += 1
                    text.removeSubrange(range)
                }
            }
        }

        let hits = order.compactMap { word in counts[word].map { (word, $0) } }
        guard occurrences > 0 else { return (0, []) }
        let normalized = max(-1, min(1, total / 3.2))
        return (normalized, hits)
    }
}
