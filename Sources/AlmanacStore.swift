import Foundation
import Observation

@MainActor
@Observable
final class AlmanacStore {

    /// 当前展示的月份。数据全部本地计算，切换即时生效。
    var key: MonthKey {
        didSet {
            guard oldValue != key else { return }
            month = AlmanacEngine.month(for: key)
            selectedDay = isCurrentMonth ? today.dayNumber : 1
            clampSelection()
            loadHolidays(for: key.year)
        }
    }

    var selectedDay: Int
    var today: Date

    private(set) var month: MonthData

    /// 放大视图要同时展示两个月，逐帧重算整月太贵，这里缓存已算过的月份
    private var monthCache: [String: MonthData] = [:]

    init(startingAt date: Date = Date()) {
        let currentKey = MonthKey(date: date)
        self.today = date
        self.key = currentKey
        self.selectedDay = date.dayNumber
        self.month = MonthData(year: currentKey.year, month: currentKey.month,
                               daysInMonth: 0, firstWeekdayOffset: 0, days: [])
        HolidayCalendar.shared.prepare()
        self.month = AlmanacEngine.month(for: currentKey)
        loadHolidays(for: currentKey.year)
    }

    // MARK: - 派生数据

    var monthName: String { "\(key.month)月" }
    var yearName: String { "\(key.year)" }
    var title: String { "\(key.year)年\(key.month)月" }

    /// 本月网格首格前面的空格数（周一开头）
    var leadingBlanks: Int { max(0, (month.days.first?.weekday ?? 1) - 1) }

    var daysInMonth: Int { month.daysInMonth }

    var cells: [CalendarCell] { month.days.map(CalendarCell.init) }

    var detail: DayDetailModel? {
        guard let info = month.dayInfo(selectedDay) else { return nil }
        return DayDetailModel(info, date: AlmanacEngine.makeDate(year: key.year, month: key.month, day: selectedDay))
    }

    var isTodaySelected: Bool { isCurrentMonth && selectedDay == today.dayNumber }

    var isCurrentMonth: Bool { key == MonthKey(date: today) }

    /// 今天在本月时返回日号，否则 nil
    var todayDay: Int? { isCurrentMonth ? today.dayNumber : nil }

    /// 从选中的这天算起，距离下一个法定节假日放假还有几天
    var holidayCountdown: String? {
        let date = AlmanacEngine.makeDate(year: key.year, month: key.month, day: selectedDay)
        guard let next = HolidayCalendar.shared.nextOffDay(from: date) else { return nil }
        if next.offset == 0 { return "\(next.day.name)假期中" }
        return "距\(next.day.name) \(next.offset) 天"
    }

    var footnote: String { "农历节气本地计算 · 美股数据在线" }

    // MARK: - 月份导航

    /// 取某个月的数据（带缓存），供放大视图并排展示
    func cachedMonth(for monthKey: MonthKey) -> MonthData {
        if let cached = monthCache[monthKey.key] { return cached }
        let data = AlmanacEngine.month(for: monthKey)
        monthCache[monthKey.key] = data
        return data
    }

    func go(to newKey: MonthKey) {
        guard newKey != key else { return }
        key = newKey
    }

    func step(_ months: Int) {
        go(to: key.offset(by: months))
    }

    func goToday() {
        let now = Date()
        today = now
        selectedDay = now.dayNumber
        key = MonthKey(date: now)
    }

    func select(day: Int) {
        guard day >= 1, day <= max(daysInMonth, 1) else { return }
        selectedDay = day
    }

    /// 跨天时调用：跟随到今天所在月份，并刷新「今天」标记
    func refreshToday() {
        let now = Date()
        let nowKey = MonthKey(date: now)
        today = now
        if key != nowKey {
            key = nowKey
            selectedDay = now.dayNumber
        }
    }

    func reload() {
        monthCache.removeAll()
        month = AlmanacEngine.month(for: key)
        loadHolidays(for: key.year)
    }

    // MARK: - 节假日（唯一需要联网的环节，失败也不影响日历）

    private func loadHolidays(for year: Int) {
        Task { [weak self] in
            await HolidayCalendar.shared.ensureYear(year)
            await HolidayCalendar.shared.refreshIfNeeded()
            guard let self, self.key.year == year else { return }
            self.monthCache.removeAll()
            self.month = AlmanacEngine.month(for: self.key)
        }
    }

    private func clampSelection() {
        guard daysInMonth > 0 else { return }
        if selectedDay < 1 || selectedDay > daysInMonth {
            selectedDay = min(max(1, selectedDay), daysInMonth)
        }
    }
}