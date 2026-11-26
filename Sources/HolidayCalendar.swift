import Foundation

struct HolidayDay: Codable, Hashable {
    let date: String   // yyyy-MM-dd
    let name: String
    let isOffDay: Bool
}

/// 中国法定节假日与调休补班。
///
/// 数据来源：https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/{year}.json
/// 内容出自每年 11 月国务院办公厅的放假通知，文件里带公告原文链接。
/// 内置 2025–2027 三年做离线兜底，缺失年份按需联网补齐。
@MainActor
final class HolidayCalendar {

    static let shared = HolidayCalendar()

    private struct FeedYear: Codable {
        let year: Int
        let days: [HolidayDay]
    }

    private let cacheDirectory: URL
    private let session: URLSession
    private let keyFormatter: DateFormatter

    private var index: [String: HolidayDay] = [:]
    private var loadedYears: Set<Int> = []
    private var lastCheckedAt: Date?

    private static let lastCheckedKey = "holidaysLastCheckedAt"
    private static let recheckInterval: TimeInterval = 6 * 3600

    init() {
        cacheDirectory = AppPaths.directory("holidays")

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        session = URLSession(configuration: config)

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.gregorianMondayFirst.timeZone
        f.dateFormat = "yyyy-MM-dd"
        keyFormatter = f

        if let stamp = UserDefaults.standard.object(forKey: Self.lastCheckedKey) as? Date {
            lastCheckedAt = stamp
        }
    }

    // MARK: - 查询

    func entry(on date: Date) -> HolidayDay? {
        index[keyFormatter.string(from: date)]
    }

    /// 从某天起（含当天）最近的放假日，返回该日与相距天数
    func nextOffDay(from date: Date, searchDays: Int = 400) -> (day: HolidayDay, offset: Int)? {
        let calendar = Calendar.gregorianMondayFirst
        let start = calendar.startOfDay(for: date)
        for offset in 0..<searchDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let entry = entry(on: day), entry.isOffDay else { continue }
            return (entry, offset)
        }
        return nil
    }

    // MARK: - 载入

    /// 启动时调用一次：内置数据 + 磁盘缓存进内存
    func prepare() {
        loadBundled()
        loadCached()
    }

    private func loadBundled() {
        guard let url = Bundle.main.url(forResource: "Holidays", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let years = try? JSONDecoder().decode([String: FeedYear].self, from: raw) else { return }
        for (_, feed) in years { merge(feed) }
    }

    private func loadCached() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        let decoder = JSONDecoder()
        for file in files where file.pathExtension == "json" {
            guard let raw = try? Data(contentsOf: file),
                  let feed = try? decoder.decode(FeedYear.self, from: raw) else { continue }
            merge(feed)
        }
    }

    private func merge(_ feed: FeedYear) {
        guard !loadedYears.contains(feed.year) else { return }
        for day in feed.days { index[day.date] = day }
        loadedYears.insert(feed.year)
    }

    // MARK: - 网络

    /// 当年 + 次年，节流刷新；失败静默（继续用内置/缓存数据）
    func refreshIfNeeded() async {
        if let last = lastCheckedAt, Date().timeIntervalSince(last) < Self.recheckInterval { return }
        lastCheckedAt = Date()
        UserDefaults.standard.set(lastCheckedAt, forKey: Self.lastCheckedKey)

        let current = MonthKey(date: Date()).year
        for year in [current, current + 1] {
            await fetchYear(year)
        }
    }

    /// 本地没有该年数据时按需补齐（例如往回翻到内置范围之外的年份）
    func ensureYear(_ year: Int) async {
        guard !loadedYears.contains(year) else { return }
        await fetchYear(year)
    }

    private func fetchYear(_ year: Int) async {
        guard let url = URL(string: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json") else { return }
        var request = URLRequest(url: url)
        request.setValue("gofree/1.0 (macOS)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return }

        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let days = raw["days"] as? [[String: Any]] else { return }

        let parsed = days.compactMap { item -> HolidayDay? in
            guard let date = item["date"] as? String,
                  let name = item["name"] as? String,
                  let isOffDay = item["isOffDay"] as? Bool else { return nil }
            return HolidayDay(date: date, name: name, isOffDay: isOffDay)
        }
        guard !parsed.isEmpty else { return }

        let feed = FeedYear(year: year, days: parsed)
        merge(feed)
        store(feed)
    }

    private func store(_ feed: FeedYear) {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(feed)
            try data.write(to: cacheDirectory.appendingPathComponent("\(feed.year).json"))
        } catch {
            // 缓存失败不影响主流程
        }
    }
}