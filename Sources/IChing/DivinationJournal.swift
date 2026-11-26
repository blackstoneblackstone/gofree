import Foundation
import Observation

/// 一次占问的记录。只存问题与六爻的爻值，卦象与断语可以据此重算，不会随版本变化失真太远。
struct DivinationRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let question: String
    let askedAt: Date
    /// 自下而上六爻，取值 6/7/8/9。
    let values: [Int]
}

/// 占问记录簿：写入 `~/Library/Application Support/gofree/divination.json`。
/// 古法「一事不二占」，所以同一个问题被问过时由调用方提示，而不是悄悄再算一次。
@MainActor
@Observable
final class DivinationJournal {
    static let shared = DivinationJournal(directory: defaultDirectory)

    private(set) var records: [DivinationRecord] = []

    private let storeURL: URL
    private let limit = 200

    static var defaultDirectory: URL { AppPaths.supportDirectory }

    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appendingPathComponent("divination.json")
        load()
    }

    /// 把问法规范化，用于判断「是否为同一件事」：忽略空白、标点与大小写。
    static func normalize(_ question: String) -> String {
        let dropped = question.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
                && !CharacterSet.punctuationCharacters.contains($0)
                && !CharacterSet.symbols.contains($0)
        }
        return String(String.UnicodeScalarView(dropped)).lowercased()
    }

    /// 像得像「同一件事」的一条旧记录。
    struct SimilarMatch {
        let record: DivinationRecord
        /// 二元组 Dice 系数，0...1
        let score: Double
        /// 是否属于「一个问法整个被另一个包含」（如「这周加仓」⊂「这周要不要加仓」）
        let contained: Bool
    }

    /// 找出措辞最接近的一条旧记录。判据两条，满足任一即为疑似同一件事：
    /// 1. 二元组 Dice 系数 ≥ 0.8（多半是错字或先后缀差别）；
    /// 2. 较短的问法整串被较长的包含，且较短者至少四个字、长度比不低于 0.5。
    /// 单纯字符重合不算——「这周要不要加仓」与「这周要不要减仓」只差一个字，但意思相反。
    func similarRecord(for question: String) -> SimilarMatch? {
        let key = Self.normalize(question)
        guard key.count >= 3 else { return nil }

        var best: SimilarMatch?
        for record in records {
            let other = Self.normalize(record.question)
            guard other != key else { continue }
            let score = Self.similarity(key, other)
            let contained = Self.contained(key, other)
            guard score >= 0.8 || contained else { continue }
            if let current = best, current.score >= score, !(contained && !current.contained) {
                continue
            }
            best = SimilarMatch(record: record, score: score, contained: contained && score < 0.8)
        }
        return best
    }

    /// 二元组 Dice 系数：把问法切成相邻两字的片段再比，比单字重合更能分辨「加仓/减仓」。
    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 1 }
        let first = bigrams(lhs)
        let second = bigrams(rhs)
        guard !first.isEmpty, !second.isEmpty else { return 0 }
        let shared = first.intersection(second).count
        return 2 * Double(shared) / Double(first.count + second.count)
    }

    /// 较短的问法是否整串被较长的包含（按字符多重集计）。
    static func contained(_ lhs: String, _ rhs: String) -> Bool {
        let shorter = Array(lhs.count <= rhs.count ? lhs : rhs)
        let longer = Array(lhs.count <= rhs.count ? rhs : lhs)
        guard shorter.count >= 4, Double(shorter.count) / Double(longer.count) >= 0.5 else { return false }
        var pool: [Character: Int] = [:]
        for character in longer { pool[character, default: 0] += 1 }
        for character in shorter {
            guard let count = pool[character], count > 0 else { return false }
            pool[character] = count - 1
        }
        return true
    }

    private static func bigrams(_ text: String) -> Set<String> {
        let characters = Array(text)
        guard characters.count > 1 else { return Set(characters.map(String.init)) }
        return Set((0..<(characters.count - 1)).map { String(characters[$0...$0 + 1]) })
    }

    func record(for question: String) -> DivinationRecord? {
        let key = Self.normalize(question)
        guard !key.isEmpty else { return nil }
        return records.first { Self.normalize($0.question) == key }
    }

    @discardableResult
    func add(question: String, values: [Int], at date: Date = Date()) -> DivinationRecord {
        let record = DivinationRecord(id: UUID(), question: question, askedAt: date, values: values)
        records.insert(record, at: 0)
        if records.count > limit { records.removeLast(records.count - limit) }
        save()
        return record
    }

    func clear() {
        records.removeAll()
        save()
    }

    /// 用记录里的爻值复原一次占问结果。
    func result(for record: DivinationRecord) -> DivinationResult? {
        DivinationEngine.judge(
            question: record.question,
            lines: DivinationEngine.cast(values: record.values),
            now: record.askedAt
        )
    }

    private struct Storage: Codable {
        var records: [DivinationRecord]
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: storeURL),
            let storage = try? JSONDecoder().decode(Storage.self, from: data)
        else { return }
        records = storage.records
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Storage(records: records)) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}