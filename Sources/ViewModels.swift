import Foundation

/// 网格单元
struct CalendarCell: Identifiable {
    var id: Int { day }
    var day: Int
    /// 1 = 周一 ... 7 = 周日
    var weekday: Int
    var label: String
    var kind: LabelKind
    var isWeekend: Bool
    var isRest: Bool
    var isWork: Bool

    init(_ info: DayInfo) {
        day = info.day
        weekday = info.weekday
        label = info.label
        kind = info.labelKind
        isWeekend = info.isWeekend
        isRest = info.isRest
        isWork = info.isWork
    }
}

/// 详情卡内容
struct DayDetailModel {
    var date: Date
    var day: Int
    var festivals: [String]
    var info: [InfoRow]

    init(_ info: DayInfo, date: Date) {
        self.date = date
        day = info.day
        festivals = info.festivals
        self.info = info.info
    }
}