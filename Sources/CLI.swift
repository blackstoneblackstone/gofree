import Foundation
import AppKit
import SwiftUI

/// 开发期命令行入口：
///   gofree --selftest
///   gofree --preview <out.png> <yyyy-MM> <day> [--more]
@MainActor
enum CLIRunner {

    static func run() -> Int32? {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else { return nil }

        switch command {
        case "--selftest":
            return SelfCheck.run()
        case "--preview":
            guard args.count >= 4 else {
                FileHandle.standardError.write(Data("用法：--preview <out.png> <yyyy-MM> <day> [--more]\n".utf8))
                return 2
            }
            return Preview.render(
                outputPath: args[1],
                monthKey: args[2],
                day: Int(args[3]) ?? 1,
                showsMore: args.dropFirst(4).contains("--more")
            )
        case "--market":
            guard args.count >= 2 else {
                FileHandle.standardError.write(Data("用法：--market <yyyy-MM-dd>\n".utf8))
                return 2
            }
            return MarketCheck.run(dayKey: args[1])
        case "--weather":
            guard args.count >= 2 else {
                FileHandle.standardError.write(Data("用法：--weather <城市>\n".utf8))
                return 2
            }
            return WeatherCheck.run(city: args[1], dateKey: args.count > 2 ? args[2] : nil)
        case "--divine":
            guard args.count >= 2 else {
                FileHandle.standardError.write(Data("用法：--divine <问题> [--seed <n>] [--method takashima|coins|yarrow]\n".utf8))
                return 2
            }
            var seed: UInt64?
            if let index = args.firstIndex(of: "--seed"), args.count > index + 1 {
                seed = UInt64(args[index + 1])
            }
            var method = DivinationMethod.takashima
            if let index = args.firstIndex(of: "--method"), args.count > index + 1,
               let parsed = DivinationMethod(rawValue: args[index + 1]) {
                method = parsed
            }
            let question = args[1].hasPrefix("--") ? "此事" : args[1]
            return DivineCheck.run(question: question, seed: seed, method: method)
        case "--llm":
            guard args.count >= 2 else {
                FileHandle.standardError.write(Data("用法：--llm <问题> [--seed <n>]\n".utf8))
                return 2
            }
            var seed: UInt64?
            if let index = args.firstIndex(of: "--seed"), args.count > index + 1 {
                seed = UInt64(args[index + 1])
            }
            return LLMCheck.run(question: args[1], seed: seed)
        default:
            return nil
        }
    }
}

// MARK: - 占卦

@MainActor
enum DivineCheck {

    static func run(question: String, seed: UInt64?, method: DivinationMethod = .takashima) -> Int32 {
        let lines = DivinationEngine.cast(method: method, seed: seed)
        guard let result = DivinationEngine.judge(question: question, lines: lines) else {
            FileHandle.standardError.write(Data("起卦失败：六十四卦数据缺失\n".utf8))
            return 1
        }

        print("问：\(question)")
        print("起卦：\(method.title)（\(method.caption)）")
        print("爻：" + lines.map { "\($0.value)" }.joined(separator: " ") + "（自下而上）")
        print("变：" + (result.changingDescription ?? "六爻皆静"))
        print("本卦：\(result.primary.symbol) \(result.primary.name)（\(result.primary.fullName)）")
        if let changed = result.changed {
            print("之卦：\(changed.symbol) \(changed.name)（\(changed.fullName)）")
        }
        print("结论：\(result.verdict.level.rawValue)　\(result.verdict.summary)")
        if !result.takashimaHighlights.isEmpty {
            print("---")
            for item in result.takashimaHighlights {
                print("高岛·\(item.source)（\(item.topic)）：\(item.text)")
            }
        }
        print("---")
        for quote in result.quotes {
            print("\(quote.title)：\(quote.text)")
        }
        print("---")
        for reason in result.reasons {
            print("· \(reason)")
        }
        return 0
    }
}

// MARK: - AI 解读

/// `--llm <问题> [--seed n]`：起一卦，把提示词打出来，再让配置好的模型解读一次。
@MainActor
enum LLMCheck {

    static func run(question: String, seed: UInt64?) -> Int32 {
        HexagramTable.prepare()
        let lines = DivinationEngine.cast(method: AppSettings.shared.divinationMethod, seed: seed)
        guard let result = DivinationEngine.judge(question: question, lines: lines) else {
            FileHandle.standardError.write(Data("起卦失败：六十四卦数据缺失\n".utf8))
            return 1
        }

        print("问：\(question)")
        print("本卦：\(result.primary.symbol) \(result.primary.name)（\(result.primary.fullName)）")
        if let changed = result.changed {
            print("之卦：\(changed.symbol) \(changed.name)（\(changed.fullName)）")
        }
        print("结论：\(result.verdict.level.rawValue)　\(result.verdict.summary)")
        print("模型：\(AppSettings.shared.llmModel)　Base URL：\(AppSettings.shared.llmBaseURL)")
        print("配置：" + (LLMClient.isConfigured ? "已就绪" : "未就绪（需要在设置里打开并填好）"))

        let interpreter = DivinationInterpreter()
        var finished = false
        let start = Date()
        interpreter.interpret(result)

        // 等 Task 跑完（CLI 没有主循环，手动泵 RunLoop）
        while !finished {
            if case .loading = interpreter.phase {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                if Date().timeIntervalSince(start) > 70 {
                    print("超时")
                    return 1
                }
                continue
            }
            finished = true
        }

        print("---")
        switch interpreter.phase {
        case let .done(text):
            print(text)
            return 0
        case let .failed(message):
            FileHandle.standardError.write(Data("解读失败：\(message)\n".utf8))
            return 1
        default:
            print("没有结果")
            return 1
        }
    }
}

// MARK: - 自检

/// 校验本地算法的输出。数据全部离线计算，不依赖网络。
@MainActor
enum SelfCheck {

    static func run() -> Int32 {
        var checks = 0
        var failures: [String] = []

        HolidayCalendar.shared.prepare()
        HexagramTable.prepare()

        func expect(_ condition: Bool, _ message: @autoclosure () -> String) {
            checks += 1
            if !condition { failures.append(message()) }
        }

        func day(_ y: Int, _ m: Int, _ d: Int) -> DayInfo {
            AlmanacEngine.dayInfo(year: y, month: m, day: d)
        }

        // 农历 / 干支 / 星期 / 星座
        let autumn = day(2026, 9, 19)
        expect(autumn.lunar == "八月初九", "2026-09-19 农历应为 八月初九，实为 \(autumn.lunar)")
        expect(autumn.ganzhi == "丙午年 丁酉月 丙申日", "2026-09-19 干支应为 丙午年 丁酉月 丙申日，实为 \(autumn.ganzhi)")
        expect(autumn.weekdayName == "星期六", "2026-09-19 应为 星期六，实为 \(autumn.weekdayName)")
        expect(autumn.constellation == "处女座", "2026-09-19 应为 处女座，实为 \(autumn.constellation)")
        expect(autumn.zodiac == "马", "2026-09-19 生肖应为 马，实为 \(autumn.zodiac)")
        expect(autumn.jieqi == nil, "2026-09-19 不是节气日，实为 \(autumn.jieqi ?? "nil")")
        expect(autumn.label == "初九" && autumn.labelKind == .lunar, "2026-09-19 网格标签应为 初九(lunar)")

        // 节气
        let bailu = day(2026, 9, 7)
        expect(bailu.jieqi == "白露", "2026-09-07 应为 白露，实为 \(bailu.jieqi ?? "nil")")
        let qiufen = day(2026, 9, 23)
        expect(qiufen.jieqi == "秋分", "2026-09-23 应为 秋分，实为 \(qiufen.jieqi ?? "nil")")
        expect(qiufen.label == "秋分" && qiufen.labelKind == .jieqi, "节气日网格标签应为节气名")
        let jieqiRow = qiufen.info.first { $0.title == "节气" }?.value ?? ""
        expect(jieqiRow.hasPrefix("秋分 第1天"), "节气日应显示「秋分 第1天…」，实为 \(jieqiRow)")

        // 闰月
        let leap = day(2025, 7, 25)
        expect(leap.lunar == "闰六月初一", "2025-07-25 应为 闰六月初一，实为 \(leap.lunar)")
        expect(leap.label == "闰六月", "闰月初一的网格标签应为 闰六月，实为 \(leap.label)")

        // 春节与放假安排
        let springFestival = day(2027, 2, 6)
        expect(springFestival.lunar == "正月初一", "2027-02-06 应为 正月初一，实为 \(springFestival.lunar)")
        expect(springFestival.festivals.contains("春节"), "2027-02-06 应含春节，实为 \(springFestival.festivals)")
        expect(springFestival.isRest, "2027-02-06 应为放假")
        let makeupWorkday = day(2027, 2, 14)
        expect(makeupWorkday.isWork && !makeupWorkday.isRest, "2027-02-14 应为补班")
        expect(day(2026, 9, 25).festivals.contains("中秋节"), "2026-09-25 应含中秋节")

        // 月结构
        let february2024 = AlmanacEngine.month(for: MonthKey(year: 2024, month: 2))
        expect(february2024.daysInMonth == 29, "2024-02 应为 29 天，实为 \(february2024.daysInMonth)")
        expect(february2024.days.count == 29, "2024-02 应有 29 条数据")
        expect(february2024.firstWeekdayOffset == 3, "2024-02-01 是周四，偏移应为 3，实为 \(firstWeekdayOffsetOf(february2024))")
        expect(february2024.days.first?.weekday == 4, "2024-02-01 应为周四")

        // 整月遍历：每天 17 项详情，标签非空
        for key in [MonthKey(year: 2026, month: 1), MonthKey(year: 2026, month: 12), MonthKey(year: 2027, month: 12)] {
            let month = AlmanacEngine.month(for: key)
            expect(month.days.count == key.daysInMonth, "\(key.key) 天数不一致")
            expect(month.days.allSatisfy { $0.info.count == 17 }, "\(key.key) 每天应有 17 项详情")
            expect(month.days.allSatisfy { !$0.label.isEmpty && !$0.lunar.isEmpty }, "\(key.key) 标签/农历不应为空")
        }

        // 美股事件（本地规则部分）
        expect(MarketStore.isFOMCDecisionDay("2026-12-09"), "2026-12-09 应为 FOMC 决议日")
        expect(!MarketStore.isFOMCDecisionDay("2026-12-10"), "2026-12-10 不是 FOMC 决议日")
        expect(MarketStore.optionExpiryKind(for: MarketStore.date(2026, 11, 20)) == .monthly,
               "2026-11-20 是月度期权到期日")
        expect(MarketStore.optionExpiryKind(for: MarketStore.date(2026, 12, 18)) == .quarterly,
               "2026-12-18 是季度期权到期（四巫日）")
        expect(MarketStore.optionExpiryKind(for: MarketStore.date(2026, 11, 13)) == nil,
               "2026-11-13 不是期权到期日")
        let badgeStore = MarketStore()
        expect(badgeStore.badges(year: 2026, month: 12)[9] == .fomc, "FOMC 日的网格标记应为 fomc")
        expect(badgeStore.badges(year: 2026, month: 12)[18] == .quadWitching,
               "2026-12-18 的网格标记应为期权到期（四巫日）")
        expect(badgeStore.badges(year: 2026, month: 11)[20] == .optionExpiry,
               "2026-11-20 的网格标记应为期权到期")

        // 美股休市：与纽交所官方日历 2026 / 2027 / 2028 逐条核对
        let holidays: [(Int, Int, Int, String)] = [
            (2026, 1, 1, "元旦"), (2026, 1, 19, "马丁·路德·金纪念日"),
            (2026, 2, 16, "总统日"), (2026, 4, 3, "耶稣受难日"),
            (2026, 5, 25, "阵亡将士纪念日"), (2026, 6, 19, "六月节"),
            (2026, 7, 3, "独立日"), (2026, 9, 7, "劳动节"),
            (2026, 11, 26, "感恩节"), (2026, 12, 25, "圣诞节"),
            (2027, 1, 1, "元旦"), (2027, 1, 18, "马丁·路德·金纪念日"),
            (2027, 2, 15, "总统日"), (2027, 3, 26, "耶稣受难日"),
            (2027, 5, 31, "阵亡将士纪念日"), (2027, 6, 18, "六月节"),
            (2027, 7, 5, "独立日"), (2027, 9, 6, "劳动节"),
            (2027, 11, 25, "感恩节"), (2027, 12, 24, "圣诞节"),
            (2027, 12, 31, "元旦"),
            (2028, 1, 17, "马丁·路德·金纪念日"), (2028, 2, 21, "总统日"),
            (2028, 4, 14, "耶稣受难日"), (2028, 5, 29, "阵亡将士纪念日"),
            (2028, 6, 19, "六月节"), (2028, 7, 4, "独立日"),
            (2028, 9, 4, "劳动节"), (2028, 11, 23, "感恩节"), (2028, 12, 25, "圣诞节")
        ]
        for (year, month, day, name) in holidays {
            let reason = USMarketCalendar.closedReason(for: MarketStore.date(year, month, day))
            expect(reason == name, "\(year)-\(month)-\(day) 应为 \(name) 休市，实际 \(reason ?? "nil")")
        }
        expect(USMarketCalendar.closedReason(for: MarketStore.date(2028, 1, 1)) == nil,
               "2028-01-01 是周六，元旦不单独休市")
        expect(USMarketCalendar.closedReason(for: MarketStore.date(2026, 11, 25)) == nil,
               "2026-11-25 是正常交易日")
        expect(USMarketCalendar.closedReason(for: MarketStore.date(2026, 8, 14)) == nil,
               "2026-08-14 是正常交易日")

        // 提前收盘（13:00 ET）
        let earlyCloses: [(Int, Int, Int, String)] = [
            (2026, 11, 27, "感恩节次日"), (2026, 12, 24, "平安夜"),
            (2027, 11, 26, "感恩节次日"),
            (2028, 7, 3, "独立日前夕"), (2028, 11, 24, "感恩节次日")
        ]
        for (year, month, day, reason) in earlyCloses {
            let actual = USMarketCalendar.earlyCloseReason(for: MarketStore.date(year, month, day))
            expect(actual == reason, "\(year)-\(month)-\(day) 应提前收盘（\(reason)），实际 \(actual ?? "nil")")
        }
        expect(USMarketCalendar.earlyCloseReason(for: MarketStore.date(2026, 11, 28)) == nil,
               "2026-11-28 不是提前收盘日")
        expect(USMarketCalendar.earlyCloseReason(for: MarketStore.date(2026, 12, 23)) == nil,
               "2026-12-23 不是提前收盘日")
        expect(USMarketCalendar.earlyCloseReason(for: MarketStore.date(2027, 12, 24)) == nil,
               "2027-12-24 是圣诞节休市日，不是提前收盘")
        expect(USMarketCalendar.earlyCloseReason(for: MarketStore.date(2026, 7, 3)) == nil,
               "2026-07-03 是独立日休市日，不是提前收盘")
        expect(USMarketCalendar.earlyCloseBeijingTime(for: MarketStore.date(2026, 11, 27)) == "次日 02:00",
               "感恩节次日 13:00 ET 对应北京次日 02:00")
        expect(USMarketCalendar.earlyCloseBeijingTime(for: MarketStore.date(2028, 7, 3)) == "次日 01:00",
               "2028-07-03 是夏令时，13:00 ET 对应北京次日 01:00")
        expect(badgeStore.badges(year: 2026, month: 11)[26] == .marketClosed,
               "2026-11-26 感恩节网格标记应为休市")

        // 事件重要级别：数据源三档 → 五星制
        expect(MarketStore.stars(forImpact: "High") == 5, "High 应为 5 星")
        expect(MarketStore.stars(forImpact: "Medium") == 3, "Medium 应为 3 星")
        expect(MarketStore.stars(forImpact: "Low") == 1, "Low 应为 1 星")

        // 指标词典：长关键词优先（Core PCE 不能被 PCE 抢走），未知指标不给提示
        expect(IndicatorGlossary.entry(for: "Core PCE Price Index m/m")?.title == "核心 PCE 物价指数",
               "Core PCE 应命中核心 PCE 词条")
        expect(IndicatorGlossary.entry(for: "Core CPI m/m")?.title == "核心 CPI",
               "Core CPI 应命中核心 CPI 而非 CPI")
        expect(IndicatorGlossary.entry(for: "Non-Farm Payrolls") != nil,
               "非农应命中词条")
        expect(IndicatorGlossary.entry(for: "Some Unknown Indicator") == nil,
               "未知指标不应命中词条")
        if let next = HolidayCalendar.shared.nextOffDay(from: MarketStore.date(2026, 11, 24)) {
            expect(next.day.name == "元旦" && next.offset == 38,
                   "2026-11-24 距元旦应为 38 天，实为 \(next.day.name) \(next.offset) 天")
        } else {
            expect(false, "2026-11-24 之后应能找到放假日")
        }
        if let next = HolidayCalendar.shared.nextOffDay(from: MarketStore.date(2026, 9, 30)) {
            expect(next.day.name == "国庆节" && next.offset == 1,
                   "2026-09-30 距国庆节应为 1 天，实为 \(next.day.name) \(next.offset) 天")
        } else {
            expect(false, "2026-09-30 之后应能找到放假日")
        }
        let today = Date()
        expect(WeatherStore.span(for: today) == .today, "今天应判为 today")
        expect(WeatherStore.span(for: Calendar.gregorianMondayFirst.date(byAdding: .day, value: 3, to: today)!) == .future,
               "三天后应判为 future")
        expect(WeatherStore.span(for: Calendar.gregorianMondayFirst.date(byAdding: .day, value: -3, to: today)!) == .history,
               "三天前应判为 history")
        expect(WeatherStore.span(for: Calendar.gregorianMondayFirst.date(byAdding: .day, value: 40, to: today)!) == .outOfRange,
               "40 天后应判为 outOfRange")
        expect(WeatherStore.dateKey(for: MarketStore.date(2026, 9, 19)) == "2026-09-19", "dateKey 格式应为 yyyy-MM-dd")
        expect(WeatherStore.condition(for: 0) == "晴", "WMO 0 应为晴")
        expect(WeatherStore.condition(for: 95) == "雷阵雨", "WMO 95 应为雷阵雨")
        expect(WeatherStore.symbol(for: 61, isDay: true) == "cloud.rain.fill", "WMO 61 图标应为 cloud.rain.fill")
        expect(WeatherStore.symbol(for: 0, isDay: false) == "moon.stars.fill", "夜间晴图标应为 moon.stars.fill")
        expect(IndicatorGlossary.entry(for: "CPI m/m")?.impact.contains("利空") == true,
               "CPI 词条应写明对美股的影响")

        // 占卦：钱币映射、卦序、取辞规则
        expect(DivinationEngine.value(backs: 0) == 6, "三字为老阴 6")
        expect(DivinationEngine.value(backs: 1) == 7, "一背为少阳 7")
        expect(DivinationEngine.value(backs: 2) == 8, "二背为少阴 8")
        expect(DivinationEngine.value(backs: 3) == 9, "三背为老阳 9")
        expect(HexagramTable.count == 64, "六十四卦数据应完整，实际 \(HexagramTable.count) 卦")
        expect(
            (1...64).allSatisfy { number in
                guard let hexagram = HexagramTable.hexagram(number: number) else { return false }
                return !hexagram.tuan.isEmpty && !hexagram.image.isEmpty && !hexagram.gloss.isEmpty
            },
            "每卦都应带《彖传》、大象与白话解读"
        )
        expect(
            HexagramTable.hexagram(number: 64)?.image.contains("火在水上") == true,
            "未济的象辞应含「火在水上」"
        )

        // 高岛易断：数据齐备 + 略筮法（必出一动爻） + 拆解与切题匹配
        expect(
            (1...64).allSatisfy { HexagramTable.hexagram(number: $0)?.hasTakashima == true },
            "每卦都应带高岛易断的卦断"
        )
        expect(
            HexagramTable.hexagram(number: 1)?.takashimaLine(at: 1)?.contains("潜龙勿用") == true,
            "《乾》初九的高岛爻断应提到「潜龙勿用」"
        )
        expect(
            HexagramTable.hexagram(number: 64)?.takashimaGeneral.contains("运途颠倒") == true,
            "《未济》的高岛卦断应含「运途颠倒」"
        )
        expect(
            (1...20).allSatisfy { seed in
                let lines = DivinationEngine.cast(method: .takashima, seed: UInt64(seed))
                return lines.count == 6 && lines.filter(\.isChanging).count == 1
            },
            "高岛略筮法每次都应恰有一动爻"
        )
        if let rawTaiFirst = HexagramTable.hexagram(number: 11)?.takashimaLine(at: 1) {
            let parsed = Takashima.parse(rawTaiFirst)
            expect(!parsed.caseStudy.isEmpty, "《泰》初九应拆出断曰占例")
            expect(parsed.items.contains { $0.topic == "问营商" }, "《泰》初九应拆出「问营商」")
        }
        if let sample = DivinationEngine.judge(question: "自检", lines: DivinationEngine.cast(seed: 7)) {
            let titles = sample.takashimaEntries.map(\.title)
            expect(sample.takashimaEntries.count == sample.changingPositions.count + 2, "高岛断语应含卦断、各动爻爻断与之卦卦断，实际 \(titles)")
            expect(titles.first == "《未济》卦断", "第一条应是本卦卦断，实际 \(titles.first ?? "nil")")
            expect(titles.contains("《未济》上九 爻断"), "四爻动应含上九爻断，实际 \(titles)")
            expect(titles.last == "《比》卦断", "末条应是之卦卦断，实际 \(titles.last ?? "nil")")
            expect(!sample.takashimaHighlights.isEmpty, "应摘出切题的高岛核心断语")
        } else {
            expect(false, "自检用起卦应能得到结果")
        }

        // 一事不二占：问法规范化 + 记录簿读写
        expect(
            DivinationJournal.normalize("这周要不要加仓？") == DivinationJournal.normalize("这周 要不要加仓"),
            "只差标点与空白的问法应视作同一个问题"
        )
        expect(
            DivinationJournal.normalize("这周要不要加仓") != DivinationJournal.normalize("这周要不要减仓"),
            "不同问题不应被判为重复"
        )
        // 蓍草（大衍之数）：老阳 3/16、少阴 7/16、少阳 5/16、老阴 1/16
        var generator = SeededGenerator(seed: 20_261_125)
        var counts = [6: 0, 7: 0, 8: 0, 9: 0]
        let samples = 4_000
        for _ in 0..<samples {
            let value = DivinationEngine.yarrowValue(using: &generator)
            counts[value, default: 0] += 1
        }
        let ratio = { (value: Int) in Double(counts[value] ?? 0) / Double(samples) }
        expect(abs(ratio(9) - 3.0 / 16) < 0.03, "老阳占比应接近 3/16，实际 \(ratio(9))")
        expect(abs(ratio(8) - 7.0 / 16) < 0.04, "少阴占比应接近 7/16，实际 \(ratio(8))")
        expect(abs(ratio(7) - 5.0 / 16) < 0.04, "少阳占比应接近 5/16，实际 \(ratio(7))")
        expect(abs(ratio(6) - 1.0 / 16) < 0.02, "老阴占比应接近 1/16，实际 \(ratio(6))")
        expect(
            DivinationEngine.cast(method: .yarrow, seed: 42).map(\.value)
                == DivinationEngine.cast(method: .yarrow, seed: 42).map(\.value),
            "同一个随机种子应得到同一卦"
        )
        // 起卦过程展示用的剩余策数：末变除以四必须回到爻值
        expect(DivinationEngine.yarrowCounts(for: 9) == [44, 40, 36], "老阳三变剩余 44/40/36")
        expect(DivinationEngine.yarrowCounts(for: 8) == [40, 36, 32], "少阴三变剩余 40/36/32")
        expect(DivinationEngine.yarrowCounts(for: 7) == [44, 36, 28], "少阳三变剩余 44/36/28")
        expect(DivinationEngine.yarrowCounts(for: 6) == [40, 32, 24], "老阴三变剩余 40/32/24")
        // AI 解读：提示词要把卦的要素都带上，endpoint 要能拼对
        if let sample = DivinationEngine.judge(
            question: "这周要不要加仓",
            lines: DivinationEngine.cast(method: .coins, seed: 7)
        ) {
            let (system, user) = DivinationPrompt.make(for: sample)
            expect(system.contains("结论"), "系统提示词要要求先给结论")
            expect(user.contains("问题：这周要不要加仓"), "提示词要带问题")
            expect(user.contains(sample.primary.name), "提示词要带本卦名")
            expect(user.contains(sample.primary.judgment), "提示词要带本卦卦辞")
            expect(user.contains("取辞规则"), "提示词要说明取辞规则")
            expect(user.contains(sample.verdict.level.rawValue), "提示词要带程序倾向")
        }
        expect(
            LLMClient.endpoint(for: "https://api.deepseek.com/v1")?.absoluteString
                == "https://api.deepseek.com/v1/chat/completions",
            "endpoint 应拼成 /chat/completions"
        )
        expect(
            LLMClient.endpoint(for: "https://api.deepseek.com/v1/")?.absoluteString
                == "https://api.deepseek.com/v1/chat/completions",
            "Base URL 末尾斜杠要吃掉"
        )
        let excerpt = DivinationPrompt.takashimaExcerpt(
            "【占】 问时运：大可成事。\n○ 问营商：得其自然之利。\n○ 问六甲：生女。",
            for: "这周要不要加仓"
        )
        expect(excerpt.contains("问营商"), "问投资的事应挑「问营商」")
        expect(!excerpt.contains("问六甲"), "不该带上不相干的分条")

        expect(
            (6...9).allSatisfy { value in
                DivinationEngine.yarrowCounts(for: value).last.map { $0 / 4 == value } ?? false
            },
            "剩余策数除以四应回到爻值"
        )

        expect(
            DivinationEngine.cast(method: .yarrow, seed: 42).map(\.value)
                != DivinationEngine.cast(method: .coins, seed: 42).map(\.value),
            "两种起卦方式应给出不同结果"
        )

        // 问法相似度：「加仓/减仓」这种只差一个反义字的不该被判成同一件事
        expect(
            DivinationJournal.similarity("这周要不要加仓", "这周要不要加仓啊") >= 0.8,
            "措辞只差一个语气词应判为相近"
        )
        expect(
            DivinationJournal.similarity("这周要不要加仓", "这周要不要减仓") < 0.8,
            "加仓与减仓意思相反，不应判为相近"
        )
        expect(
            DivinationJournal.contained("这周加仓", "这周要不要加仓"),
            "「这周加仓」应被「这周要不要加仓」包含"
        )
        expect(
            !DivinationJournal.contained("这周加仓", "这周要不要减仓"),
            "「这周加仓」不应被判为被「这周要不要减仓」包含"
        )

        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gofree-selftest-\(UUID().uuidString)")
        let journal = DivinationJournal(directory: tempDirectory)
        let casted = DivinationEngine.cast(seed: 7)
        journal.add(question: "自检问题", values: casted.map(\.value))
        expect(journal.records.count == 1, "记录簿应写入一条占问")
        expect(
            journal.record(for: "自检问题？") != nil,
            "带标点的相同问法应能查到记录"
        )
        expect(
            journal.record(for: "另一个问题") == nil,
            "没问过的问题不应查到记录"
        )
        expect(
            journal.record(for: "自检问题？") != nil,
            "完全相同（仅标点不同）的问法应能命中记录"
        )
        expect(
            journal.similarRecord(for: "自检问题啊") != nil,
            "措辞相近的问法应被提示为疑似同一件事"
        )
        expect(
            journal.similarRecord(for: "换一个完全不同的问题") == nil,
            "不相关的问题不应触发提示"
        )
        let reloaded = DivinationJournal(directory: tempDirectory)
        expect(reloaded.records.count == 1, "记录簿应能持久化后重新读取")
        expect(
            reloaded.records.first.map { journal.result(for: $0)?.verdict.level } != nil,
            "记录应能复原出占断结果"
        )
        try? FileManager.default.removeItem(at: tempDirectory)
        expect(HexagramTable.hexagram(lower: .qian, upper: .kun)?.number == 11, "地天泰应为第 11 卦")
        expect(HexagramTable.hexagram(lower: .li, upper: .kan)?.number == 63, "水火既济应为第 63 卦")
        expect(HexagramTable.hexagram(number: 1)?.lines.count == 6, "乾卦应有六爻")

        let stillLines = DivinationEngine.cast(values: [7, 7, 7, 7, 7, 7])
        if let still = DivinationEngine.judge(question: "自检", lines: stillLines) {
            expect(still.primary.number == 1 && still.changed == nil, "六个少阳应为乾卦且无变卦")
            expect(still.changingPositions.isEmpty, "六爻皆静不应有变爻")
            expect(still.quotes.count == 1 && still.quotes[0].title.contains("卦辞"),
                   "六爻皆静应取本卦卦辞")
        } else {
            expect(false, "六爻皆静应能断出结果")
        }

        let movingLines = DivinationEngine.cast(values: [9, 7, 7, 7, 7, 7])
        if let moving = DivinationEngine.judge(question: "自检", lines: movingLines) {
            expect(moving.changingPositions == [1], "初爻老阳应变，变爻应为 1")
            expect(moving.quotes.first?.title == "《乾》初九", "一爻变应取《乾》初九，实为 \(moving.quotes.first?.title ?? "nil")")
            expect(moving.changed?.number == 44, "乾初爻变应之姤（第 44 卦）")
        } else {
            expect(false, "一爻变应能断出结果")
        }

        let allMoving = DivinationEngine.cast(values: [9, 9, 9, 9, 9, 9])
        if let six = DivinationEngine.judge(question: "自检", lines: allMoving) {
            expect(six.quotes.first?.title == "《乾》用九", "乾六爻皆变应用九")
            expect(six.quotes.first?.text.contains("群龙无首") == true, "用九原文应含「群龙无首」")
        } else {
            expect(false, "乾六爻皆变应能断出结果")
        }

        let emptySize = DivinationWindow.contentSize(previewResult: nil)
        let resultSize = DivinationWindow.contentSize(
            previewResult: DivinationEngine.judge(
                question: "自检",
                lines: DivinationEngine.cast(seed: 7)
            )
        )
        expect(resultSize.height > emptySize.height + 100,
               "有结果时窗口应变高（空态 \(Int(emptySize.height)) → 结果态 \(Int(resultSize.height))）")
        expect(resultSize.width == DivinationView.width,
               "占一事窗口宽度应为 \(Int(DivinationView.width))，实为 \(Int(resultSize.width))")

        // 真实踩过的坑：从菜单栏浮窗里点「占一卦」，新窗口被压在浮窗下面，
        // 用户看到的就是「点了没反应」。造一个高层级浮窗，验证它会被收起来。
        let fakePopover = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        fakePopover.level = .statusBar
        fakePopover.orderFrontRegardless()
        DivinationWindow.open(
            previewResult: DivinationEngine.judge(question: "自检", lines: DivinationEngine.cast(seed: 7))
        )
        expect(!fakePopover.isVisible, "开占卦窗口时应把菜单栏浮窗收起来")
        fakePopover.close()

        expect(Verdict.make(score: 0.6, summary: "").level == .go, "分数 0.6 应判可行")
        expect(Verdict.make(score: 0, summary: "").level == .cautious, "分数 0 应判审慎")
        expect(Verdict.make(score: -0.6, summary: "").level == .avoid, "分数 -0.6 应判不宜")

        print("自检完成：\(checks) 项检查，\(failures.count) 项失败")
        for failure in failures {
            print("✗ \(failure)")
        }
        return failures.isEmpty ? 0 : 1
    }

    private static func firstWeekdayOffsetOf(_ month: MonthData) -> Int {
        month.firstWeekdayOffset
    }
}

// MARK: - 美股事件探测

/// `gofree --weather 杭州`：直接打印当前天气，用于验证抓取链路
@MainActor
enum WeatherCheck {

    static func run(city: String, dateKey: String?) -> Int32 {
        let store = WeatherStore()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.gregorianMondayFirst.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let date: Date
        if let dateKey, let parsed = formatter.date(from: dateKey) {
            date = parsed
        } else {
            date = Date()
        }
        store.load(city: city, date: date)
        let deadline = Date().addingTimeInterval(30)
        while store.isLoading || (store.day == nil && store.errorMessage == nil && Date() < deadline) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        guard let weather = store.day else {
            print("✗ 天气获取失败：\(store.errorMessage ?? "超时")")
            return 1
        }
        print("城市：\(weather.locationName)　日期：\(weather.dateKey)")
        print("天气：\(weather.condition)（\(weather.symbol)）")
        if let temperature = weather.temperature {
            print("当前：\(Int(temperature.rounded()))°（体感 \(Int((weather.apparent ?? temperature).rounded()))°）")
        }
        if let high = weather.high, let low = weather.low {
            print("最高 / 最低：\(Int(high.rounded()))° / \(Int(low.rounded()))°")
        }
        let fetched = weather.fetchedAt.formatted(date: .numeric, time: .shortened)
        let stale = store.isStale ? "（缓存未更新）" : ""
        print((weather.isHistory ? "来源：历史实况" : "来源：预报") + stale + "　抓取于 " + fetched)
        return 0
    }
}

/// `gofree --market 2026-12-09`：直接打印某天的美股事件，用于验证抓取链路
@MainActor
enum MarketCheck {

    static func run(dayKey: String) -> Int32 {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = MarketStore.beijing
        guard let date = formatter.date(from: dayKey) else {
            print("✗ 日期格式应为 yyyy-MM-dd，得到：\(dayKey)")
            return 2
        }

        let store = MarketStore()
        var finished = false
        Task {
            await store.loadNow(for: date)
            finished = true
        }

        let deadline = Date().addingTimeInterval(30)
        while !finished && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        let day = store.day
        print("\(dayKey) FOMC=\(day.isFOMC) 期权到期=\(day.isOptionExpiry) 四巫日=\(day.isQuadWitching)")
        print("财报 \(day.earnings.count) 家（大公司 \(day.majorEarningsCount) 家）")
        for item in day.earnings.prefix(10) {
            print("  \(item.isMajor ? "★ " : "  ")\(item.symbol) \(item.name) \(item.session) EPS \(item.eps)")
        }
        print("经济数据 \(day.economy.count) 条")
        for item in day.economy.prefix(8) {
            print("  \(item.time) \(item.name) 预期 \(item.consensus) 前值 \(item.previous)")
        }
        if !finished {
            print("⚠︎ 超时：网络请求尚未结束")
            return 1
        }
        return 0
    }
}

// MARK: - 预览渲染

@MainActor
enum Preview {

    /// 预览用的可变状态盒子（脱离 SwiftUI State 也能驱动 Binding）
    final class MoreState {
        var value: Bool
        init(value: Bool) { self.value = value }
    }

    /// 用环境变量 TC_PREVIEW_DARK=1 渲染深色模式，便于自查
    static var darkMode: Bool {
        if let flag = ProcessInfo.processInfo.environment["TC_PREVIEW_DARK"] {
            return flag == "1"
        }
        return AppSettings.shared.appearance == .dark
    }

    /// TC_PREVIEW_SETTINGS=1 时渲染配置中心窗口，用于截图核对
    private static var previewsSettings: Bool {
        ProcessInfo.processInfo.environment["TC_PREVIEW_SETTINGS"] == "1"
    }

    /// TC_PREVIEW_EXPANDED=1 时渲染「连续两个月」放大视图
    private static var previewsExpanded: Bool {
        ProcessInfo.processInfo.environment["TC_PREVIEW_EXPANDED"] == "1"
    }

    /// TC_PREVIEW_DIVINE=<问题> 时渲染「占一事」窗口，TC_PREVIEW_SEED 可固定卦象
    private static var previewQuestion: String? {
        ProcessInfo.processInfo.environment["TC_PREVIEW_DIVINE"]
    }

    private static var previewSeed: UInt64? {
        ProcessInfo.processInfo.environment["TC_PREVIEW_SEED"].flatMap(UInt64.init)
    }

    /// TC_PREVIEW_DIVINE_HISTORY=1 时给截图塞几条往占记录
    private static var previewsHistory: Bool {
        ProcessInfo.processInfo.environment["TC_PREVIEW_DIVINE_HISTORY"] == "1"
    }

    private static var previewsTakashima: Bool {
        ProcessInfo.processInfo.environment["TC_PREVIEW_DIVINE_TAKASHIMA"] == "1"
    }

    private static var previewsTuan: Bool {
        ProcessInfo.processInfo.environment["TC_PREVIEW_DIVINE_TUAN"] == "1"
    }

    /// TC_PREVIEW_LLM_TEXT 给截图塞一段 AI 解读，并把开关打开
    private static var previewLLMText: String? {
        ProcessInfo.processInfo.environment["TC_PREVIEW_LLM_TEXT"]
    }

    /// TC_PREVIEW_LLM_ERROR 给截图塞一个失败态（验证报错在界面上长什么样）
    private static var previewLLMError: String? {
        ProcessInfo.processInfo.environment["TC_PREVIEW_LLM_ERROR"]
    }

    /// TC_PREVIEW_DIVINE_CASTING=3 时把起卦过程冻结在第 3 爻
    private static var previewCastProgress: Int? {
        ProcessInfo.processInfo.environment["TC_PREVIEW_DIVINE_CASTING"].flatMap(Int.init)
    }

    /// 截图时的起卦方式：TC_PREVIEW_DIVINE_METHOD=yarrow
    private static var previewMethod: DivinationMethod {
        guard
            let value = ProcessInfo.processInfo.environment["TC_PREVIEW_DIVINE_METHOD"],
            let method = DivinationMethod(rawValue: value)
        else { return .coins }
        return method
    }

    private static func sampleRecords() -> [DivinationRecord] {
        let samples: [(String, UInt64, TimeInterval)] = [
            ("这周要不要加仓", 3, -86_400 * 3),
            ("要不要接这个项目", 11, -86_400 * 9),
            ("年底换不换工作", 42, -86_400 * 16)
        ]
        return samples.map { question, seed, offset in
            DivinationRecord(
                id: UUID(),
                question: question,
                askedAt: Date().addingTimeInterval(offset),
                values: DivinationEngine.cast(seed: seed).map(\.value)
            )
        }
    }

    static func render(outputPath: String, monthKey: String, day: Int, showsMore: Bool) -> Int32 {
        if let question = previewQuestion {
            if question == "-" {
                return snapshot(
                    AnyView(
                        DivinationView()
                            .environment(\.colorScheme, Preview.darkMode ? .dark : .light)
                    ),
                    width: DivinationView.width,
                    outputPath: outputPath
                )
            }
            // 截图会临时改设置，渲完要还原，别把开关写进用户的 UserDefaults
            let previousMethod = AppSettings.shared.divinationMethod
            let previousLLM = AppSettings.shared.llmEnabled
            AppSettings.shared.divinationMethod = previewMethod
            if previewLLMText != nil || previewLLMError != nil {
                AppSettings.shared.llmEnabled = true
            }
            defer {
                AppSettings.shared.divinationMethod = previousMethod
                AppSettings.shared.llmEnabled = previousLLM
            }
            let lines = DivinationEngine.cast(method: previewMethod, seed: previewSeed ?? 20_261_125)
            let result = DivinationEngine.judge(question: question, lines: lines)
            return snapshot(
                AnyView(
                    DivinationView(
                        previewQuestion: question,
                        previewResult: result,
                        previewRecords: previewsHistory ? sampleRecords() : nil,
                        previewExpandedHistory: previewsHistory,
                        previewShowsTuan: previewsTuan,
                        previewShowsTakashima: previewsTakashima,
                        previewCastProgress: previewCastProgress,
                        previewLLMText: previewLLMText,
                        previewLLMError: previewLLMError
                    )
                    .environment(\.colorScheme, Preview.darkMode ? .dark : .light)
                ),
                width: DivinationView.width,
                outputPath: outputPath
            )
        }

        if previewsSettings {
            return snapshot(
                AnyView(
                    ZStack {
                        Color(nsColor: .windowBackgroundColor)
                        SettingsView(settings: AppSettings.shared, calendarService: CalendarService())
                    }
                    .environment(\.colorScheme, Preview.darkMode ? .dark : .light)
                ),
                width: 340,
                outputPath: outputPath
            )
        }

        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else {
            print("✗ 月份格式应为 yyyy-MM，得到：\(monthKey)")
            return 2
        }

        let store = AlmanacStore()
        store.key = MonthKey(year: year, month: month)
        store.select(day: day)

        MarketStore.offlineOnly = true        // 截图只读缓存，不联网
        WeatherStore.offlineOnly = true

        if previewsExpanded {
            let expanded = ZStack {
                Color(nsColor: .windowBackgroundColor)
                ExpandedCalendarView(store: store, calendarService: CalendarService())
            }
            .environment(\.colorScheme, Preview.darkMode ? .dark : .light)
            return snapshot(AnyView(expanded), width: ExpandedCalendarView.width, outputPath: outputPath)
        }

        let more = MoreState(value: showsMore)
        let root = ZStack {
            Color(nsColor: .windowBackgroundColor)
            PopoverView(
                store: store,
                calendarService: CalendarService(),
                onQuit: {},
                showsMore: Binding(get: { more.value }, set: { more.value = $0 })
            )
        }
        .environment(\.colorScheme, Preview.darkMode ? .dark : .light)

        return snapshot(AnyView(root), width: PopoverView.width, outputPath: outputPath)
    }

    /// ImageRenderer 无法栅格化 ScrollView，这里用离屏窗口真实布局后截图
    private static func snapshot(_ root: AnyView, width: CGFloat, outputPath: String) -> Int32 {
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 900)
        hosting.layoutSubtreeIfNeeded()

        let fitting = hosting.fittingSize
        let height = max(200, fitting.height)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        // 让 onAppear 里的异步数据（美股缓存）和依赖 layout 的浮层稳定下来再截图
        for _ in 0..<8 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
        }

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("✗ 创建位图失败")
            return 1
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        window.orderOut(nil)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("✗ 编码 PNG 失败")
            return 1
        }
        do {
            try png.write(to: URL(fileURLWithPath: outputPath))
            print("✓ 已输出预览图：\(outputPath)（\(Int(hosting.bounds.width))x\(Int(hosting.bounds.height)) @2x）")
            return 0
        } catch {
            print("✗ 写入失败：\(error.localizedDescription)")
            return 1
        }
    }
}