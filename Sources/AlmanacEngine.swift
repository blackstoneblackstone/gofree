import Foundation

/// 日历与黄历数据的唯一来源：全部在本地计算。
/// 农历、干支、节气、星宿、黄历详情来自 lunar-swift（寿星天文历体系）；
/// 法定放假 / 调休补班来自 HolidayCalendar（国务院公告数据）。
@MainActor
enum AlmanacEngine {

    // MARK: - 月

    static func month(for key: MonthKey) -> MonthData {
        let count = key.daysInMonth
        var days: [DayInfo] = []
        days.reserveCapacity(count)
        for day in 1...count {
            days.append(dayInfo(year: key.year, month: key.month, day: day))
        }
        return MonthData(
            year: key.year,
            month: key.month,
            daysInMonth: count,
            firstWeekdayOffset: (days.first?.weekday ?? 1) - 1,
            days: days
        )
    }

    // MARK: - 日

    static func dayInfo(year: Int, month: Int, day: Int) -> DayInfo {
        let solar = Solar(year: year, month: month, day: day)
        let lunar = solar.lunar
        let date = makeDate(year: year, month: month, day: day)

        let weekday = date.isoWeekdayMondayFirst
        let holiday = HolidayCalendar.shared.entry(on: date)
        let jieqi = lunar.jieQi.isEmpty ? nil : lunar.jieQi
        let festivals = festivalNames(solar: solar, lunar: lunar)
        let label = gridLabel(jieqi: jieqi, festivals: festivals, lunar: lunar)

        return DayInfo(
            date: String(format: "%04d-%02d-%02d", year, month, day),
            day: day,
            weekday: weekday,
            weekdayName: date.weekdayChineseName,
            lunar: lunarFullName(lunar),
            ganzhi: "\(lunar.yearInGanZhiExact)年 \(lunar.monthInGanZhi)月 \(lunar.dayInGanZhi)日",
            zodiac: lunar.yearShengXiaoExact,
            constellation: solar.xingZuo + "座",
            jieqi: jieqi,
            festivals: festivals,
            label: label.text,
            labelKind: label.kind,
            isWeekend: weekday >= 6,
            isRest: holiday?.isOffDay ?? false,
            isWork: holiday.map { !$0.isOffDay } ?? false,
            info: infoRows(solar: solar, lunar: lunar)
        )
    }

    // MARK: - 标签

    /// 网格短标签优先级：节气 > 节日 > 农历日名（初一显示月名）
    private static func gridLabel(jieqi: String?, festivals: [String], lunar: Lunar) -> (text: String, kind: LabelKind) {
        if let jieqi { return (jieqi, .jieqi) }
        // 网格只有一格宽，只放得下短名；长名（世界XX日一类）留在详情卡里
        if let festival = festivals.first(where: { $0.count <= 4 }) {
            return (festival, .festival)
        }
        if lunar.dayInChinese == "初一" { return (lunarMonthName(lunar.monthInChinese), .lunar) }
        return (lunar.dayInChinese, .lunar)
    }

    // MARK: - 农历写法

    /// lunar.monthInChinese 不带「月」字，且「冬」「腊」「闰六」要走站点写法
    private static func lunarMonthName(_ raw: String) -> String {
        if raw.hasPrefix("闰") {
            return "闰" + String(raw.dropFirst()) + "月"
        }
        switch raw {
        case "冬": return "十一月"
        case "腊": return "十二月"
        default: return raw + "月"
        }
    }

    private static func lunarFullName(_ lunar: Lunar) -> String {
        lunarMonthName(lunar.monthInChinese) + lunar.dayInChinese
    }

    // MARK: - 节日

    private static func festivalNames(solar: Solar, lunar: Lunar) -> [String] {
        // 只取传统节日与公历节日；放假/补班由 HolidayCalendar 单独标注，不再拼「XX假期」
        var seen = Set<String>()
        return (lunar.festivals + solar.festivals).filter { seen.insert($0).inserted }
    }

    // MARK: - 17 项详情

    private static func infoRows(solar: Solar, lunar: Lunar) -> [InfoRow] {
        [
            InfoRow(title: "生肖", value: lunar.yearShengXiaoExact),
            InfoRow(title: "星座", value: solar.xingZuo + "座"),
            InfoRow(title: "彭祖百忌", value: "\(lunar.pengZuGan)，\(lunar.pengZuZhi)。"),
            InfoRow(title: "胎神占方", value: lunar.dayPositionTai),
            InfoRow(title: "年五行", value: lunar.yearNaYin),
            InfoRow(title: "季节", value: seasonName(lunar.season)),
            InfoRow(title: "月五行", value: lunar.monthNaYin),
            InfoRow(title: "星宿", value: "\(lunar.xiu)\(lunar.zheng)\(lunar.animal)"),
            InfoRow(title: "日五行", value: lunar.dayNaYin),
            InfoRow(title: "节气", value: jieQiDetail(solar: solar, lunar: lunar)),
            InfoRow(title: "儒略日", value: String(format: "%.1f", solar.julianDay)),
            InfoRow(title: "佛历年", value: "\(lunar.year + 543)年"),
            InfoRow(title: "伊斯兰历", value: islamicDate(solar: solar)),
            InfoRow(title: "冲", value: "\(lunar.dayChongShengXiao) （\(lunar.dayChong)）"),
            InfoRow(title: "煞", value: lunar.daySha),
            InfoRow(title: "六曜", value: lunar.liuYao),
            InfoRow(title: "十二神", value: "\(lunar.zhiXing)执位"),
        ]
    }

    /// "白露 第13天（距秋分4天）"
    private static func jieQiDetail(solar: Solar, lunar: Lunar) -> String {
        // 当天正是节气时，「上一个节气」就是它自己；「下一个节气」同理也是它自己，得往后挪一天取
        let isTermDay = !lunar.jieQi.isEmpty
        let prev = isTermDay ? JieQi(name: lunar.jieQi, solar: solar) : lunar.prevJieQi
        let next = isTermDay ? solar.nextDay(days: 1).lunar.nextJieQi : lunar.nextJieQi
        let dayOfTerm = dayDiff(from: prev.solar, to: solar) + 1
        let remaining = dayDiff(from: solar, to: next.solar)
        return "\(prev.name) 第\(dayOfTerm)天（距\(next.name)\(remaining)天）"
    }

    /// 孟春/仲秋/季冬 → 春季/秋季/冬季
    private static func seasonName(_ season: String) -> String {
        switch season.last {
        case "春": return "春季"
        case "夏": return "夏季"
        case "秋": return "秋季"
        case "冬": return "冬季"
        default: return season
        }
    }

    private static func islamicDate(solar: Solar) -> String {
        let date = makeDate(year: solar.year, month: solar.month, day: solar.day)
        let c = Calendar.islamic.dateComponents([.year, .month, .day], from: date)
        return String(format: "%d年%02d月%02d日", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - 日期工具

    static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return Calendar.gregorianMondayFirst.date(from: c) ?? Date()
    }

    private static func dayDiff(from start: Solar, to end: Solar) -> Int {
        let a = makeDate(year: start.year, month: start.month, day: start.day)
        let b = makeDate(year: end.year, month: end.month, day: end.day)
        return Calendar.gregorianMondayFirst.dateComponents([.day], from: a, to: b).day ?? 0
    }
}