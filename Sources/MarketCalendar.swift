import SwiftUI

// MARK: - 模型

/// 一家公司的财报安排
struct EarningsEvent: Identifiable, Hashable, Codable {
    var id: String { symbol }
    let symbol: String
    let name: String
    /// 盘前 / 盘后 / 不确定
    let session: String
    /// 市场一致预期 EPS，可能为空
    let eps: String
    /// 标普 500 成分股（用于判定「大公司」）
    var isMajor: Bool = false
}

/// 一条经济数据
struct EconomicEvent: Identifiable, Hashable, Codable {
    var id: String { "\(time)|\(name)" }
    /// 北京时间 HH:mm，全天事件为空串
    let time: String
    let name: String
    /// High / Medium / Low
    let impact: String
    let consensus: String
    let previous: String
    /// 重要级别 1–5 星（5 最高），由数据源的 impact 映射
    var stars: Int = 3
}

/// 某一天的美股市场事件
struct MarketDay {
    /// 已排序：大公司在前
    var earnings: [EarningsEvent] = []
    var majorEarningsCount = 0
    var economy: [EconomicEvent] = []
    /// FOMC 议息决议日
    var isFOMC = false
    /// 月度期权到期（每月第三个周五）
    var isOptionExpiry = false
    /// 季度期权到期（三/六/九/十二月的第三个周五，四巫日）
    var isQuadWitching = false
    /// 美股全天休市
    var isMarketClosed = false
    /// 休市的原因，如「马丁·路德·金纪念日」
    var closedReason: String?
    /// 提前收盘的原因，如「感恩节次日」
    var earlyCloseReason: String?
    /// 提前收盘对应的北京时间，如「次日 02:00」
    var earlyCloseBeijingTime: String?

    var isEmpty: Bool {
        earnings.isEmpty && economy.isEmpty
            && !isFOMC && !isOptionExpiry && !isMarketClosed && earlyCloseReason == nil
    }
}

/// 网格上的事件标记
enum MarketBadge: Equatable {
    case marketClosed
    case fomc
    case earnings
    case quadWitching
    case optionExpiry
}

// MARK: - 数据源

/// 美股事件：财报日、重要经济数据、FOMC 决议、期权到期。
///
/// - 整月财报日来自 Alpha Vantage 财报日历（horizon=3month，一次请求覆盖未来三个月，demo key 即可）；
///   「大公司」用内置的标普 500 成分股名单筛，只有大公司才在网格上打点；
/// - 经济数据来自 forex factory 的周历镜像（无需 key，只覆盖本周，按重要性 High 过滤）；
/// - FOMC 决议日、期权到期日（每月第三个周五 / 四巫日）纯本地计算，不联网。
@MainActor
@Observable
final class MarketStore {

    private(set) var day = MarketDay()
    private(set) var isLoading = false
    /// 有大公司财报的日期（整月角标用）
    private(set) var earningsDays: Set<String> = []

    /// 预览/截图时置 true：只用磁盘缓存，不联网
    static var offlineOnly = false

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    /// 整月财报（按 yyyy-MM-dd 分组，已含 isMajor）
    private var earningsByDate: [String: [EarningsEvent]] = [:]
    private var economyByDate: [String: [EconomicEvent]] = [:]
    private var monthFetchedAt: Date?
    private var economyFetchedAt: Date?
    private var loadTask: Task<Void, Never>?
    private var lastRequest = Date.distantPast

    // MARK: 对外接口

    /// 切换选中日时调用：先给出本地已知的部分，再异步补网络数据
    func load(for date: Date) {
        prepare(for: date)
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.refresh(date: date)
        }
    }

    /// 命令行探测用：等数据真的取回来
    func loadNow(for date: Date) async {
        prepare(for: date)
        loadTask?.cancel()
        await refresh(date: date)
    }

    /// 网格角标：FOMC > 大公司财报 > 期权到期
    func badges(year: Int, month: Int) -> [Int: MarketBadge] {
        var result: [Int: MarketBadge] = [:]
        let key = MonthKey(year: year, month: month)
        for day in 1...key.daysInMonth {
            let date = Self.date(year, month, day)
            let dayKey = Self.key(for: date)
            if USMarketCalendar.closedReason(for: date) != nil {
                result[day] = .marketClosed
            } else if Self.isFOMCDecisionDay(dayKey) {
                result[day] = .fomc
            } else if earningsDays.contains(dayKey) {
                result[day] = .earnings
            } else if let kind = Self.optionExpiryKind(for: date) {
                result[day] = kind == .quarterly ? .quadWitching : .optionExpiry
            }
        }
        return result
    }

    // MARK: 内部

    private func prepare(for date: Date) {
        hydrateCaches()

        var fresh = MarketDay()
        let dayKey = Self.key(for: date)
        if let reason = USMarketCalendar.closedReason(for: date) {
            fresh.isMarketClosed = true
            fresh.closedReason = reason
        }
        if let reason = USMarketCalendar.earlyCloseReason(for: date) {
            fresh.earlyCloseReason = reason
            fresh.earlyCloseBeijingTime = USMarketCalendar.earlyCloseBeijingTime(for: date)
        }
        fresh.isFOMC = Self.isFOMCDecisionDay(dayKey)
        if let kind = Self.optionExpiryKind(for: date) {
            fresh.isOptionExpiry = true
            fresh.isQuadWitching = kind == .quarterly
        }
        let all = earningsByDate[dayKey] ?? []
        fresh.earnings = all.filter { $0.isMajor } + all.filter { !$0.isMajor }
        fresh.majorEarningsCount = all.filter { $0.isMajor }.count
        fresh.economy = economyByDate[dayKey] ?? []
        day = fresh
    }

    /// 把磁盘缓存读进内存：截图预览（offlineOnly）也能出数据
    private func hydrateCaches() {
        if monthFetchedAt == nil,
           let cached: [CachedMonth] = Self.readCache(name: "earnings-month"),
           let month = cached.first {
            earningsByDate = month.days
            earningsDays = Set(month.days.filter { $0.value.contains { $0.isMajor } }.keys)
            monthFetchedAt = month.fetchedAt
        }
        if economyByDate.isEmpty,
           let cached: [CachedWeek] = Self.readCache(name: "economy-week"),
           let week = cached.first {
            economyByDate = Dictionary(uniqueKeysWithValues: week.days.map { ($0.date, $0.events) })
            economyFetchedAt = week.fetchedAt
        }
    }

    // MARK: 网络

    private func refresh(date: Date) async {
        let dayKey = Self.key(for: date)
        isLoading = true
        defer { isLoading = false }

        _ = await fetchEarningsMonth()

        if let grouped = await fetchEconomyWeek() {
            economyByDate = grouped
        }

        // 网络回来后按最新的整月数据重算一次当日内容
        if Self.key(for: date) == dayKey {
            prepare(for: date)
        }
    }

    private func throttle() async {
        let gap = Date().timeIntervalSince(lastRequest)
        if gap < 1.0 {
            try? await Task.sleep(nanoseconds: UInt64((1.0 - gap) * 1_000_000_000))
        }
        lastRequest = Date()
    }

    /// Alpha Vantage 财报日历：horizon=3month 一次覆盖未来三个月
    @discardableResult
    private func fetchEarningsMonth() async -> Bool {
        if let fetchedAt = monthFetchedAt, Date().timeIntervalSince(fetchedAt) < 6 * 3600,
           !earningsByDate.isEmpty {
            return false
        }
        if Self.offlineOnly { return false }

        guard let url = URL(string:
            "https://www.alphavantage.co/query?function=EARNINGS_CALENDAR&horizon=3month&apikey=demo")
        else { return false }
        await throttle()
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else { return false }

        let rows = Self.parseCSV(text)
        guard rows.count > 1 else { return false }
        let header = rows[0]
        guard let symbolIndex = header.firstIndex(of: "symbol"),
              let nameIndex = header.firstIndex(of: "name"),
              let dateIndex = header.firstIndex(of: "reportDate"),
              let timeIndex = header.firstIndex(of: "timeOfTheDay"),
              let estimateIndex = header.firstIndex(of: "estimate") else { return false }
        let columns = rows.dropFirst().map { $0.count }.max() ?? 0
        guard columns > max(symbolIndex, nameIndex, dateIndex, timeIndex, estimateIndex) else { return false }

        let majors = Self.majorSymbols()
        var grouped: [String: [EarningsEvent]] = [:]
        for row in rows.dropFirst() {
            guard row.count > max(symbolIndex, nameIndex, dateIndex, timeIndex, estimateIndex) else { continue }
            let dayKey = row[dateIndex]
            guard dayKey.count == 10 else { continue }
            let raw = row[timeIndex]
            let session = raw.contains("pre-market") ? "盘前" : (raw.contains("post-market") ? "盘后" : "")
            let estimate = row[estimateIndex]
            let symbol = row[symbolIndex]
            let event = EarningsEvent(
                symbol: symbol,
                name: Self.displayName(row[nameIndex]),
                session: session,
                eps: estimate.isEmpty ? "" : "$\(estimate)",
                isMajor: majors.contains(Self.normalizedSymbol(symbol))
            )
            grouped[dayKey, default: []].append(event)
        }

        earningsByDate = grouped
        earningsDays = Set(grouped.filter { $0.value.contains { $0.isMajor } }.keys)
        monthFetchedAt = Date()
        Self.writeCache([CachedMonth(fetchedAt: monthFetchedAt ?? Date(), days: grouped)], name: "earnings-month")
        return true
    }

    /// forex factory 周历镜像：一次返回本周全部事件，带重要性
    private func fetchEconomyWeek() async -> [String: [EconomicEvent]]? {
        if let fetchedAt = economyFetchedAt, Date().timeIntervalSince(fetchedAt) < 6 * 3600,
           !economyByDate.isEmpty {
            return economyByDate
        }
        if Self.offlineOnly { return economyByDate.isEmpty ? nil : economyByDate }
        guard let url = URL(string: "https://nfs.faireconomy.media/ff_calendar_thisweek.json") else { return nil }
        await throttle()
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.timeZone = Self.beijing
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = Self.beijing

        var grouped: [String: [EconomicEvent]] = [:]
        for row in rows {
            guard let country = row["country"] as? String, country == "USD",
                  let impact = row["impact"] as? String, impact == "High" || impact == "Medium",
                  let title = row["title"] as? String,
                  let raw = row["date"] as? String,
                  let parsed = formatter.date(from: raw) else { continue }
            let event = EconomicEvent(
                time: timeFormatter.string(from: parsed),
                name: title,
                impact: impact,
                consensus: (row["forecast"] as? String) ?? "",
                previous: (row["previous"] as? String) ?? "",
                stars: MarketStore.stars(forImpact: impact)
            )
            grouped[dayFormatter.string(from: parsed), default: []].append(event)
        }
        for key in grouped.keys {
            grouped[key]?.sort { first, second in
                first.stars != second.stars ? first.stars > second.stars : first.time < second.time
            }
        }

        let week = CachedWeek(
            weekStart: Self.weekStart(for: Date()),
            fetchedAt: Date(),
            days: grouped.map { CachedWeek.Day(date: $0.key, events: $0.value) }
        )
        economyFetchedAt = week.fetchedAt
        Self.writeCache([week], name: "economy-week")
        return grouped
    }

    /// 数据源的三档重要性映射到 1–5 星：High 5 星、Medium 3 星、Low 1 星
    static func stars(forImpact impact: String) -> Int {
        switch impact {
        case "High": return 5
        case "Medium": return 3
        case "Low": return 1
        default: return 3
        }
    }

    // MARK: 本地规则

    /// FOMC 议息决议日（会议第二天），来源：美联储官网 2026–2027 会议日程
    private static let fomcDecisionKeys: Set<String> = [
        "2026-01-28", "2026-03-18", "2026-04-29", "2026-06-17",
        "2026-07-29", "2026-09-16", "2026-10-28", "2026-12-09",
        "2027-01-27", "2027-03-17", "2027-04-28", "2027-06-09",
        "2027-07-28", "2027-09-15", "2027-10-27", "2027-11-17"
    ]

    static func isFOMCDecisionDay(_ dayKey: String) -> Bool {
        fomcDecisionKeys.contains(dayKey)
    }

    enum ExpiryKind { case monthly, quarterly }

    /// 期权到期：每月第三个周五；三/六/九/十二月是季度到期（四巫日）
    static func optionExpiryKind(for date: Date) -> ExpiryKind? {
        let calendar = Calendar.gregorianMondayFirst
        let day = calendar.component(.day, from: date)
        guard date.isoWeekdayMondayFirst == 5, (15...21).contains(day) else { return nil }
        let month = calendar.component(.month, from: date)
        return [3, 6, 9, 12].contains(month) ? .quarterly : .monthly
    }

    // MARK: 工具

    static let beijing: TimeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private static var majorSymbolCache: Set<String>?

    /// 内置的标普 500 成分股（Resources/sp500.txt），用于判定「大公司」
    private static func majorSymbols() -> Set<String> {
        if let cached = majorSymbolCache { return cached }
        var symbols: Set<String> = []
        if let url = Bundle.main.url(forResource: "sp500", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            for line in text.split(separator: "\n") {
                let symbol = line.trimmingCharacters(in: .whitespaces)
                if !symbol.isEmpty, !symbol.hasPrefix("#") {
                    symbols.insert(normalizedSymbol(symbol))
                }
            }
        }
        majorSymbolCache = symbols
        return symbols
    }

    /// BRK.B 与 BRK-B 视为同一个代码
    private static func normalizedSymbol(_ raw: String) -> String {
        raw.uppercased().replacingOccurrences(of: "-", with: ".")
    }

    /// 便于自检与预览：按北京时间中午构造某一天
    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.gregorianMondayFirst.date(from: components) ?? Date()
    }

    /// 网格每次重绘都会查 30 天，复用 formatter 避免反复分配
    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = beijing
        return formatter
    }()

    static func key(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    /// 事件所在周的周一（用于判断周历是否已加载）
    private static func weekStart(for date: Date) -> String {
        let calendar = Calendar.gregorianMondayFirst
        let start = calendar.startOfDay(for: date)
        let offset = -(date.isoWeekdayMondayFirst - 1)
        let monday = calendar.date(byAdding: .day, value: offset, to: start) ?? start
        return key(for: monday)
    }

    /// "Analog Devices, Inc." → "Analog Devices"；全大写名字转成首字母大写
    private static func displayName(_ raw: String) -> String {
        let name = raw == raw.uppercased() ? raw.capitalized : raw
        let short = shortCompanyName(name)
        // "HP" 这类短名保持大写，别变成 "Hp"
        return short.count <= 3 ? short.uppercased() : short
    }

    private static func shortCompanyName(_ raw: String) -> String {
        var name = raw
        for suffix in [" Inc.", " Inc", " Corporation", " Corp.", " Corp", " Incorporated",
                       " Limited", " Ltd.", " Company", " Co.", " plc", " PLC",
                       " Common Stock", " Holdings Inc.", " Public Limited"] {
            if name.hasSuffix(suffix) { name = String(name.dropLast(suffix.count)) }
        }
        while let last = name.last, last == "," || last == " " || last == "." || last == "&" {
            name.removeLast()
        }
        return name
    }

    /// 极简 CSV 解析：支持双引号包裹与字段内逗号
    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var quoted = false
        for character in text {
            if character == "\"" {
                quoted.toggle()
            } else if character == ",", !quoted {
                row.append(field)
                field = ""
            } else if character.isNewline, !quoted {
                row.append(field)
                field = ""
                if !row.allSatisfy({ $0.isEmpty }) { rows.append(row) }
                row = []
            } else {
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            if !row.allSatisfy({ $0.isEmpty }) { rows.append(row) }
        }
        return rows
    }

    // MARK: 磁盘缓存

    private struct CachedWeek: Codable {
        struct Day: Codable {
            let date: String
            let events: [EconomicEvent]
        }
        let weekStart: String
        let fetchedAt: Date
        let days: [Day]
    }

    private struct CachedMonth: Codable {
        let fetchedAt: Date
        let days: [String: [EarningsEvent]]
    }

    private static var cacheDirectory: URL { AppPaths.directory("market") }

    private static func readCache<T: Decodable>(name: String) -> T? {
        let url = cacheDirectory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func writeCache<T: Encodable>(_ value: T, name: String) {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: cacheDirectory.appendingPathComponent("\(name).json"))
    }
}
// MARK: - 美股休市

/// 美股休市与提前收盘（NYSE / Nasdaq 规则）。
/// 规则实现后已与纽交所官方日历 2026 / 2027 / 2028 三年逐条核对：
/// 2026 十天、2027 十天、2028 九天（2028 年元旦落在周六，不放假）。
enum USMarketCalendar {

    /// 当天全天休市的节日名；nil 表示正常交易日
    static func closedReason(for date: Date) -> String? {
        let (year, month, day) = ymd(of: date)
        for candidate in year - 1...year + 1 {
            for holiday in holidays(in: candidate)
            where holiday.year == year && holiday.month == month && holiday.day == day {
                return holiday.name
            }
        }
        return nil
    }

    /// 当天是否提前到 13:00 ET 收盘，返回原因
    static func earlyCloseReason(for date: Date) -> String? {
        let (year, month, day) = ymd(of: date)
        let weekday = weekdayOf(year: year, month: month, day: day)

        // 感恩节次日
        let thanksgiving = thanksgivingDay(year: year)
        if month == 11, day == thanksgiving + 1 { return "感恩节次日" }
        // 平安夜（圣诞节本身不是周六时才提前收盘；周六则平安夜直接休市）
        if month == 12, day == 24,
           let christmas = observed(year: year, month: 12, day: 25),
           christmas.month == 12, christmas.day == 25 {
            return "平安夜"
        }
        // 独立日前夕（7/4 落在周二至周五时，7/3 提前收盘）
        if month == 7, day == 3, (2...5).contains(weekday),
           let independence = observed(year: year, month: 7, day: 4),
           independence.month == 7, independence.day == 4 {
            return "独立日前夕"
        }
        return nil
    }

    /// 13:00 ET 对应的北京时间，如「次日 02:00」（夏令时是 01:00）
    static func earlyCloseBeijingTime(for date: Date) -> String? {
        let (year, month, day) = ymd(of: date)
        let newYork = TimeZone(identifier: "America/New_York") ?? .current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 13
        components.timeZone = newYork
        guard let close = Calendar(identifier: .gregorian).date(from: components) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let time = formatter.string(from: close)
        let sameDay = ymd(of: close) == (year, month, day)
        return sameDay ? time : "次日 \(time)"
    }

    // MARK: 节日表

    struct Holiday {
        let year: Int
        let month: Int
        let day: Int
        let name: String
    }

    /// 按官方规则补出某年的休市日（含观察日顺延/前置）
    static func holidays(in year: Int) -> [Holiday] {
        var result: [Holiday] = []

        // 元旦：落在周六则休市日提前到上一年 12/31
        if let newYear = observed(year: year, month: 1, day: 1) {
            result.append(Holiday(year: newYear.year, month: newYear.month, day: newYear.day, name: "元旦"))
        }
        // 马丁·路德·金纪念日：一月第三个周一
        result.append(named("马丁·路德·金纪念日", nth: 3, weekday: 2, year: year, month: 1))
        // 华盛顿诞辰（总统日）：二月第三个周一
        result.append(named("总统日", nth: 3, weekday: 2, year: year, month: 2))
        // 耶稣受难日：复活节前的周五
        let easterDate = easter(year: year)
        if let goodFriday = offset(year: year, month: easterDate.month, day: easterDate.day, by: -2) {
            result.append(Holiday(year: goodFriday.year, month: goodFriday.month, day: goodFriday.day, name: "耶稣受难日"))
        }
        // 阵亡将士纪念日：五月最后一个周一
        result.append(named("阵亡将士纪念日", nth: -1, weekday: 2, year: year, month: 5))
        // 六月节：6/19
        if let juneteenth = observed(year: year, month: 6, day: 19) {
            result.append(Holiday(year: juneteenth.year, month: juneteenth.month, day: juneteenth.day, name: "六月节"))
        }
        // 独立日：7/4
        if let independence = observed(year: year, month: 7, day: 4) {
            result.append(Holiday(year: independence.year, month: independence.month, day: independence.day, name: "独立日"))
        }
        // 劳动节：九月第一个周一
        result.append(named("劳动节", nth: 1, weekday: 2, year: year, month: 9))
        // 感恩节：十一月第四个周四
        result.append(named("感恩节", nth: 4, weekday: 5, year: year, month: 11))
        // 圣诞节：12/25
        if let christmas = observed(year: year, month: 12, day: 25) {
            result.append(Holiday(year: christmas.year, month: christmas.month, day: christmas.day, name: "圣诞节"))
        }
        return result
    }

    private static func thanksgivingDay(year: Int) -> Int {
        nthDay(4, weekday: 5, year: year, month: 11)
    }

    private static func named(_ name: String, nth: Int, weekday: Int, year: Int, month: Int) -> Holiday {
        let day = nth > 0
            ? nthDay(nth, weekday: weekday, year: year, month: month)
            : lastDay(weekday: weekday, year: year, month: month)
        return Holiday(year: year, month: month, day: day, name: name)
    }

    /// 顺延规则：周六提前到周五，周日推后到周一
    private static func observed(year: Int, month: Int, day: Int) -> (year: Int, month: Int, day: Int)? {
        switch weekdayOf(year: year, month: month, day: day) {
        case 7: return offset(year: year, month: month, day: day, by: -1)
        case 1: return offset(year: year, month: month, day: day, by: 1)
        default: return (year, month, day)
        }
    }

    // MARK: 日历工具（UTC，纯算术，不受本机时区影响）

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private static func ymd(of date: Date) -> (year: Int, month: Int, day: Int) {
        let calendar = Calendar.gregorianMondayFirst
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return (components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func utcDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return utcCalendar.date(from: components)
    }

    /// 1 = 周日 … 7 = 周六
    private static func weekdayOf(year: Int, month: Int, day: Int) -> Int {
        guard let date = utcDate(year: year, month: month, day: day) else { return 1 }
        return utcCalendar.component(.weekday, from: date)
    }

    private static func offset(year: Int, month: Int, day: Int, by days: Int) -> (year: Int, month: Int, day: Int)? {
        guard let date = utcDate(year: year, month: month, day: day),
              let shifted = utcCalendar.date(byAdding: .day, value: days, to: date) else { return nil }
        let components = utcCalendar.dateComponents([.year, .month, .day], from: shifted)
        return (components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        guard let date = utcDate(year: year, month: month, day: 1),
              let range = utcCalendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    private static func weekdays(weekday: Int, year: Int, month: Int) -> [Int] {
        (1...daysInMonth(year: year, month: month)).filter {
            weekdayOf(year: year, month: month, day: $0) == weekday
        }
    }

    private static func nthDay(_ ordinal: Int, weekday: Int, year: Int, month: Int) -> Int {
        let days = weekdays(weekday: weekday, year: year, month: month)
        guard days.count >= ordinal else { return 1 }
        return days[ordinal - 1]
    }

    private static func lastDay(weekday: Int, year: Int, month: Int) -> Int {
        weekdays(weekday: weekday, year: year, month: month).last ?? 1
    }

    /// 复活节（Anonymous Gregorian algorithm）
    private static func easter(year: Int) -> (month: Int, day: Int) {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return (month, day)
    }
}
