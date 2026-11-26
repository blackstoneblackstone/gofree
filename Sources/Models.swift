import Foundation

// MARK: - 基础模型

enum LabelKind: String, Hashable {
    case lunar
    case jieqi
    case festival
}

struct InfoRow: Hashable, Identifiable {
    var title: String
    var value: String

    var id: String { title }
}

struct DayInfo: Hashable, Identifiable {
    /// "2026-09-19"
    var date: String
    var day: Int
    /// 1 = 周一 ... 7 = 周日
    var weekday: Int
    var weekdayName: String
    /// 完整农历，如 "八月初九"、"闰六月初一"
    var lunar: String
    /// "丙午年 丁酉月 丙申日"
    var ganzhi: String
    var zodiac: String
    var constellation: String
    var jieqi: String?
    var festivals: [String]
    /// 网格里的短标签：农历日名（初一显示月名）、节气名或节日名
    var label: String
    var labelKind: LabelKind
    var isWeekend: Bool
    /// 法定放假（国务院公告）
    var isRest: Bool
    /// 调休补班
    var isWork: Bool
    var info: [InfoRow]

    var id: String { date }
}

struct MonthData {
    var year: Int
    var month: Int
    var daysInMonth: Int
    /// 本月 1 号前面要空几格（周一开头）
    var firstWeekdayOffset: Int
    var days: [DayInfo]

    func dayInfo(_ day: Int) -> DayInfo? {
        days.first { $0.day == day }
    }
}

struct MonthKey: Hashable, Comparable {
    var year: Int
    var month: Int

    init(year: Int, month: Int) {
        var y = year
        var m = month
        while m < 1 { m += 12; y -= 1 }
        while m > 12 { m -= 12; y += 1 }
        self.year = y
        self.month = m
    }

    init(date: Date) {
        let c = Calendar.gregorianMondayFirst.dateComponents([.year, .month], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1)
    }

    var key: String { String(format: "%04d-%02d", year, month) }

    var title: String { "\(year)年\(month)月" }

    func offset(by months: Int) -> MonthKey {
        MonthKey(year: year, month: month + months)
    }

    var firstDay: Date {
        Calendar.gregorianMondayFirst.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    var daysInMonth: Int {
        Calendar.gregorianMondayFirst.range(of: .day, in: .month, for: firstDay)?.count ?? 30
    }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }
}

// MARK: - 日历工具

extension Calendar {
    static var gregorianMondayFirst: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // 周一
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        c.locale = Locale(identifier: "zh_CN")
        return c
    }

    /// 回历（伊斯兰历）
    static var islamic: Calendar {
        var c = Calendar(identifier: .islamic)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }
}

extension Date {
    /// 1 = 周一 ... 7 = 周日
    var isoWeekdayMondayFirst: Int {
        let apple = Calendar.gregorianMondayFirst.component(.weekday, from: self) // 1 = 周日
        return (apple + 5) % 7 + 1
    }

    var weekdayChineseName: String {
        let names = ["", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
        return names[max(1, min(7, isoWeekdayMondayFirst))]
    }

    var monthKey: MonthKey { MonthKey(date: self) }

    var dayNumber: Int { Calendar.gregorianMondayFirst.component(.day, from: self) }

    var startOfDay: Date { Calendar.gregorianMondayFirst.startOfDay(for: self) }
}