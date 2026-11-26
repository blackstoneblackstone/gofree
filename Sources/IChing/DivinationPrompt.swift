import Foundation

/// 解卦用的提示词：把本地已经算好的卦象与《高岛易断》断语摊给模型，让它紧扣用户原问题给出直接解答。
enum DivinationPrompt {

    /// 把这一卦的卦象、卦爻辞、《高岛易断》切题断语与断例、程序研判全摊给模型。
    static func make(for result: DivinationResult) -> (system: String, user: String) {
        let system = """
        你是一位精研《周易》与高岛嘉右卫门《高岛易断》的解卦师。用户会向你提出一个具体问题，并附上刚起出的卦象、\
        《周易》卦爻辞与《高岛易断》中的切题断语及断例。

        你的唯一目标：**全程紧扣用户的原问题来解卦**，把《高岛易断》的断语与卦理直接翻译成针对“这件事”的判断与做法。
        严禁脱离用户问题去泛泛科普卦象、堆砌术语，或写一段套在任何问题上都成立的通用解卦文。

        要求：
        1. 第一行单独输出一行定性标签，严格从以下三选一：【结论】可行、【结论】审慎、【结论】不宜（必须与你下文对用户问题的实际判断完全一致；例如建议“先不加仓/暂缓/观望”应标【结论】不宜或【结论】审慎，绝不能标【结论】可行）。空一行后再写正文。
        2. 正文第一句话必须点出用户问题里的核心事项并给出直接结论（如问“要不要/能不能”直接答可做、暂缓或不宜；如问“怎么样/什么时候/选哪个/为什么”直接顺着问法给明确判断），不打太极，不说“看情况”“因人而异”。
        3. 第二段结合《高岛易断》切题【占】断语与动爻【断曰】的核心意思，逐一对应到用户问的这件事的现实处境（例如时机、阻力、人际、得失）；历史占例只借其理，不要复述明治旧事。
        4. 第三段用本卦到之卦的走向，针对用户问的这件事给出 1–2 句具体可落地的做法或避坑提醒。
        5. 引用卦辞、爻辞或高岛断语时，只用材料里提供的原句，不要自行编造。
        6. 正文不要输出 Markdown 标题或列表符号，用平实自然的 2–3 个短段，200–320 字。
        7. 不要用“仅供娱乐/请自行决定/不做投资建议”之类的免责套话收尾（界面底部已有免责声明）。
        """

        var lines: [String] = []
        lines.append("【用户所问问题】\(result.question)")
        lines.append("问题：\(result.question)")
        lines.append("本卦：\(result.primary.fullName)（\(result.primary.name)），" + (result.changingDescription ?? "六爻皆静"))
        lines.append("本卦卦辞：\(result.primary.judgment)")
        if !result.primary.image.isEmpty {
            lines.append("大象：\(result.primary.image)")
        }
        if let changed = result.changed, changed.number != result.primary.number {
            lines.append("之卦：\(changed.fullName)（\(changed.name)）")
            lines.append("之卦卦辞：\(changed.judgment)")
        } else {
            lines.append("之卦：无（六爻不变）")
        }
        lines.append("取辞规则：\(result.quoteRule)")
        for quote in result.quotes {
            lines.append("取辞·\(quote.title)：\(quote.text)")
        }
        if !result.takashimaHighlights.isEmpty {
            lines.append("高岛易断·切题【占】：")
            for item in result.takashimaHighlights {
                let tag = item.isPrimary ? "（主）" : "（参）"
                lines.append("  \(item.source)\(tag) \(item.topic)：\(item.text)")
            }
        }
        for index in result.changingPositions.prefix(2) {
            if let raw = result.primary.takashimaLine(at: index) {
                let parsed = Takashima.parse(raw)
                if !parsed.caseStudy.isEmpty {
                    let excerpt = parsed.caseStudy.count <= 280
                        ? parsed.caseStudy
                        : String(parsed.caseStudy.prefix(280)) + "…"
                    lines.append("高岛易断·\(DivinationResult.positionName(index))断例：\(excerpt)")
                }
            }
        }
        lines.append("程序倾向：\(result.verdict.level.rawValue)（\(result.verdict.summary)）")
        lines.append("程序理由：" + result.reasons.joined(separator: "；"))
        lines.append("【作答要求】请把「\(result.question)」作为主线，开头直接回答这个问题，并用上面的高岛断语与卦象解释原因与具体做法。")

        return (system, lines.joined(separator: "\n"))
    }

    /// 高岛卦断是按「问营商 / 问功名 / 问家宅…」分条写的，按问题里的词挑相关的条目。
    static func takashimaExcerpt(_ text: String, for question: String, maxLength: Int = 420) -> String {
        Takashima.excerpt(text, for: question, maxLength: maxLength)
    }
}
