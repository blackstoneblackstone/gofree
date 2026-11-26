import Foundation
import Observation

/// 某一天的天气（今天带当前温度，其他日期只有高低温与天况）
struct WeatherDay: Codable, Hashable {
    var dateKey: String            // yyyy-MM-dd
    var cacheKey: String?          // 城市|日期，用于判断当前显示的是不是同一份查询
    var locationName: String
    var temperature: Double?       // 仅今天有
    var apparent: Double?
    var high: Double?
    var low: Double?
    var condition: String
    var symbol: String
    var isHistory: Bool
    var fetchedAt: Date
}

/// 天气：按「城市 + 日期」缓存，今天/未来 30 分钟内不重复请求，历史数据永久缓存
@MainActor
@Observable
final class WeatherStore {

    /// 截图时只读缓存，不联网
    static var offlineOnly = false

    private(set) var day: WeatherDay?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// 显示的是缓存，且这次没能刷新成功（网络断了/超时）
    private(set) var isStale = false

    enum Span {
        case today, future, history, outOfRange
    }

    private struct Place: Codable {
        var name: String
        var latitude: Double
        var longitude: Double
    }

    private struct Cache: Codable {
        var days: [String: WeatherDay] = [:]
        var places: [String: Place] = [:]
    }

    private let session: URLSession
    private let cacheFile: URL
    private var cache = Cache()
    private var loadTask: Task<Void, Never>?
    private var currentKey: String?
    private var lastDate: Date?

    private static let freshTTL: TimeInterval = 30 * 60
    private static let forecastDays = 15

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        session = URLSession(configuration: config)

        cacheFile = AppPaths.supportDirectory.appendingPathComponent("weather.json")

        cache = readCache()
        pruneCache()

        observeCityChanges()
    }

    /// 配置中心改了城市就立刻重拉（即使菜单栏窗口当时没打开）。
    /// 用 Observation 的追踪替代原来的 Combine 订阅：每次触发后重新挂一次。
    private func observeCityChanges() {
        withObservationTracking {
            _ = AppSettings.shared.weatherCity
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.observeCityChanges()
                guard let date = self.lastDate else { return }
                self.load(city: AppSettings.shared.weatherCity, date: date, force: true)
            }
        }
    }

    // MARK: - 对外

    func load(city: String, date: Date, force: Bool = false) {
        let city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        lastDate = date
        guard !city.isEmpty else {
            day = nil
            errorMessage = nil
            return
        }
        let dateKey = Self.dateKey(for: date)
        let key = "\(city)|\(dateKey)"
        currentKey = key

        // 超出预报范围：不发请求，直接给一句明确的话（历史数据由 archive 接口覆盖）
        if case .outOfRange = Self.span(for: date) {
            day = nil
            isLoading = false
            errorMessage = WeatherError.outOfRange.errorDescription
            return
        }

        // 城市或日期变了，先把旧数据清掉，避免短暂显示上一个城市
        if day?.cacheKey != key { day = nil }
        errorMessage = nil

        // 有缓存就先显示出来，过期的也照显示（下面会去刷新）：网络不通时这是唯一的希望
        if !force, var cached = cache.days[key] {
            cached.cacheKey = key          // 老缓存文件里没有这个字段，补上
            day = cached
            isStale = !isFresh(cached)
            if isFresh(cached) { return }
        } else {
            isStale = false
        }

        guard !Self.offlineOnly else { return }

        loadTask?.cancel()
        isLoading = true
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let fresh = try await self.fetch(city: city, date: date, dateKey: dateKey)
                guard self.currentKey == key else { return }
                self.day = fresh
                self.cache.days[key] = fresh
                self.isStale = false
                self.writeCache()
                self.errorMessage = nil
            } catch {
                guard self.currentKey == key else { return }
                // 手里有缓存就继续显示它（标明未更新），别把已经看到的天气清成一句报错
                if self.day == nil {
                    self.errorMessage = error.localizedDescription
                } else {
                    self.isStale = true
                    self.errorMessage = nil
                }
            }
            self.isLoading = false
        }
    }

    /// 这天属于哪一类（决定用预报接口还是历史接口）
    static func span(for date: Date, now: Date = Date()) -> Span {
        let calendar = Calendar.gregorianMondayFirst
        let target = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if days == 0 { return .today }
        if days > 0 { return days <= forecastDays ? .future : .outOfRange }
        return .history
    }

    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.gregorianMondayFirst.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - 网络

    private func fetch(city: String, date: Date, dateKey: String) async throws -> WeatherDay {
        switch Self.span(for: date) {
        case .outOfRange:
            throw WeatherError.outOfRange
        case .today, .future:
            return try await fetchForecast(city: city, dateKey: dateKey, withCurrent: Self.span(for: date) == .today)
        case .history:
            return try await fetchArchive(city: city, dateKey: dateKey)
        }
    }

    private func fetchForecast(city: String, dateKey: String, withCurrent: Bool) async throws -> WeatherDay {
        let place = try await place(for: city)
        var items = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "start_date", value: dateKey),
            URLQueryItem(name: "end_date", value: dateKey),
        ]
        if withCurrent {
            items.append(URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"))
        }
        let json = try await getJSON(url: "https://api.open-meteo.com/v1/forecast", query: items)

        guard let daily = json["daily"] as? [String: Any],
              let codes = daily["weather_code"] as? [Int], let code = codes.first else {
            throw WeatherError.noData(dateKey)
        }
        let highs = daily["temperature_2m_max"] as? [Double]
        let lows = daily["temperature_2m_min"] as? [Double]

        var temperature: Double?
        var apparent: Double?
        var symbolDay = true
        if let current = json["current"] as? [String: Any] {
            temperature = current["temperature_2m"] as? Double
            apparent = current["apparent_temperature"] as? Double
            symbolDay = (current["is_day"] as? Int ?? 1) == 1
        }

        return WeatherDay(
            dateKey: dateKey,
            cacheKey: "\(city)|\(dateKey)",
            locationName: place.name,
            temperature: temperature,
            apparent: apparent,
            high: highs?.first,
            low: lows?.first,
            condition: Self.condition(for: code),
            symbol: Self.symbol(for: code, isDay: symbolDay),
            isHistory: false,
            fetchedAt: Date()
        )
    }

    private func fetchArchive(city: String, dateKey: String) async throws -> WeatherDay {
        let place = try await place(for: city)
        let items = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "start_date", value: dateKey),
            URLQueryItem(name: "end_date", value: dateKey),
        ]
        let json = try await getJSON(url: "https://archive-api.open-meteo.com/v1/archive", query: items)

        guard let daily = json["daily"] as? [String: Any],
              let codes = daily["weather_code"] as? [Int], let code = codes.first else {
            throw WeatherError.noData(dateKey)
        }
        let highs = daily["temperature_2m_max"] as? [Double]
        let lows = daily["temperature_2m_min"] as? [Double]
        guard highs?.first != nil, lows?.first != nil else { throw WeatherError.noData(dateKey) }

        return WeatherDay(
            dateKey: dateKey,
            cacheKey: "\(city)|\(dateKey)",
            locationName: place.name,
            temperature: nil,
            apparent: nil,
            high: highs?.first,
            low: lows?.first,
            condition: Self.condition(for: code),
            symbol: Self.symbol(for: code, isDay: true),
            isHistory: true,
            fetchedAt: Date()
        )
    }

    private func place(for city: String) async throws -> Place {
        if let cached = cache.places[city] { return cached }
        let items = [
            URLQueryItem(name: "name", value: city),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "zh"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let json = try await getJSON(url: "https://geocoding-api.open-meteo.com/v1/search", query: items)

        guard let results = json["results"] as? [[String: Any]], let first = results.first,
              let name = first["name"] as? String,
              let latitude = first["latitude"] as? Double,
              let longitude = first["longitude"] as? Double else {
            throw WeatherError.cityNotFound(city)
        }
        let place = Place(name: name, latitude: latitude, longitude: longitude)
        cache.places[city] = place
        writeCache()
        return place
    }

    private func getJSON(url: String, query: [URLQueryItem]) async throws -> [String: Any] {
        var components = URLComponents(string: url)!
        components.queryItems = query
        guard let url = components.url else { throw WeatherError.badResponse }
        var request = URLRequest(url: url)
        request.setValue("gofree/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherError.badStatus(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WeatherError.badResponse
        }
        return json
    }

    // MARK: - 缓存

    private func isFresh(_ day: WeatherDay) -> Bool {
        if day.isHistory { return true }
        return Date().timeIntervalSince(day.fetchedAt) < Self.freshTTL
    }

    /// 只保留最近 60 天的天气缓存，避免文件无限增长
    private func pruneCache() {
        guard let cutoff = Calendar.gregorianMondayFirst.date(byAdding: .day, value: -60, to: Date()) else { return }
        let cutoffKey = Self.dateKey(for: cutoff)
        let before = cache.days.count
        cache.days = cache.days.filter { $0.key.split(separator: "|").last.map(String.init) ?? "" >= cutoffKey }
        if cache.days.count != before { writeCache() }
    }

    private func readCache() -> Cache {
        guard let data = try? Data(contentsOf: cacheFile) else { return Cache() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Cache.self, from: data)) ?? Cache()
    }

    private func writeCache() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cache) else { return }
        try? FileManager.default.createDirectory(
            at: cacheFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: cacheFile)
    }

    // MARK: - WMO 天气代码

    enum WeatherError: LocalizedError {
        case badResponse
        case badStatus(Int)
        case cityNotFound(String)
        case noData(String)
        case outOfRange

        var errorDescription: String? {
            switch self {
            case .badResponse: return "天气数据格式异常"
            case .badStatus(let code): return "天气服务返回 HTTP \(code)"
            case .cityNotFound(let city): return "找不到城市「\(city)」"
            case .noData(let date): return "\(date) 暂无天气数据"
            case .outOfRange: return "超出 15 天预报范围"
            }
        }
    }

    static func condition(for code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1: return "晴间多云"
        case 2: return "多云"
        case 3: return "阴"
        case 45, 48: return "雾"
        case 51, 53, 55: return "毛毛雨"
        case 56, 57: return "冻雨"
        case 61: return "小雨"
        case 63: return "中雨"
        case 65: return "大雨"
        case 66, 67: return "冻雨"
        case 71: return "小雪"
        case 73: return "中雪"
        case 75: return "大雪"
        case 77: return "米雪"
        case 80, 81: return "阵雨"
        case 82: return "强阵雨"
        case 85, 86: return "阵雪"
        case 95: return "雷阵雨"
        case 96, 99: return "雷暴冰雹"
        default: return "未知"
        }
    }

    static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0, 1: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}