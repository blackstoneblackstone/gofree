import Foundation

/// 《周易》六十四卦原文，来自中文维基文库（公有领域），随 App 打包为 `iching.json`。
@MainActor
enum HexagramTable {
    private static var byNumber: [Int: Hexagram] = [:]
    private static var byBits: [String: Hexagram] = [:]

    private struct RawLine: Decodable {
        let name: String
        let text: String
    }

    private struct RawTakashima: Decodable {
        let general: String
        let lines: [String]
    }

    private struct RawHexagram: Decodable {
        let number: Int
        let name: String
        let symbol: String
        let upper: String
        let lower: String
        let judgment: String
        let tuan: String
        let image: String
        let gloss: String
        let lines: [RawLine]
        let use: RawLine?
        let takashima: RawTakashima?
    }

    private struct RawTable: Decodable {
        let hexagrams: [RawHexagram]
    }

    static func prepare() {
        guard byNumber.isEmpty else { return }
        guard
            let url = Bundle.main.url(forResource: "iching", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let table = try? JSONDecoder().decode(RawTable.self, from: data)
        else { return }

        for raw in table.hexagrams {
            guard let upper = Trigram(name: raw.upper), let lower = Trigram(name: raw.lower) else { continue }
            let hexagram = Hexagram(
                number: raw.number,
                name: raw.name,
                symbol: raw.symbol,
                upper: upper,
                lower: lower,
                judgment: raw.judgment,
                tuan: raw.tuan,
                image: raw.image,
                gloss: raw.gloss,
                lines: raw.lines.map { HexagramLine(name: $0.name, text: $0.text) },
                extra: raw.use.map { HexagramLine(name: $0.name, text: $0.text) },
                takashimaGeneral: raw.takashima?.general ?? "",
                takashimaLines: raw.takashima?.lines ?? []
            )
            byNumber[hexagram.number] = hexagram
            byBits[key(hexagram.bits)] = hexagram
        }
    }

    static var count: Int {
        byNumber.count
    }

    static func hexagram(number: Int) -> Hexagram? {
        byNumber[number]
    }

    /// `bits` 自下而上六爻。
    static func hexagram(bits: [Bool]) -> Hexagram? {
        byBits[key(bits)]
    }

    static func hexagram(lower: Trigram, upper: Trigram) -> Hexagram? {
        byBits[key(lower.bits + upper.bits)]
    }

    private static func key(_ bits: [Bool]) -> String {
        bits.map { $0 ? "1" : "0" }.joined()
    }
}