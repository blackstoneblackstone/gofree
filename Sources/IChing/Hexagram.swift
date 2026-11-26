import Foundation

struct HexagramLine: Hashable {
    let name: String
    let text: String
}

struct Hexagram: Identifiable, Hashable {
    let number: Int
    let name: String
    let symbol: String
    let upper: Trigram
    let lower: Trigram
    let judgment: String
    /// 《彖传》：解释卦辞义理。
    let tuan: String
    /// 《象传》大象：取象 + 「君子以…」。
    let image: String
    /// 大象的白话解读（本 App 自撰，不是古籍原文）。
    let gloss: String
    /// 自下而上六爻：初、二、三、四、五、上。
    let lines: [HexagramLine]
    /// 乾卦用九、坤卦用六。
    let extra: HexagramLine?
    /// 高岛嘉右卫门《高岛易断》的卦断（明治时代著作，已进入公有领域）。
    let takashimaGeneral: String
    /// 高岛易断的六爻断语，自下而上；缺字时为空串。
    let takashimaLines: [String]

    var id: Int { number }

    var bits: [Bool] { lower.bits + upper.bits }

    /// 「下乾上坤」
    var structure: String { "下\(lower.rawValue)上\(upper.rawValue)" }

    /// 「乾为天」「地天泰」式全名。
    var fullName: String {
        upper == lower ? "\(name)为\(upper.nature)" : "\(upper.nature)\(lower.nature)\(name)"
    }

    /// 第 index 爻的高岛断语（1...6，自下而上）。
    func takashimaLine(at index: Int) -> String? {
        let text = takashimaLines.indices.contains(index - 1) ? takashimaLines[index - 1] : ""
        return text.isEmpty ? nil : text
    }

    var hasTakashima: Bool {
        !takashimaGeneral.isEmpty || takashimaLines.contains { !$0.isEmpty }
    }

    /// 第 index 爻（1...6，自下而上）。
    func line(at index: Int) -> HexagramLine? {
        guard lines.indices.contains(index - 1) else { return nil }
        return lines[index - 1]
    }
}