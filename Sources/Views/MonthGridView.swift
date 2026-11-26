import SwiftUI

struct MonthGridView: View {
    let cells: [CalendarCell]
    let leadingBlanks: Int
    let selectedDay: Int
    let todayDay: Int?
    let month: Int
    let onSelect: (Int) -> Void
    /// 按日号索引的美股事件角标（财报 / FOMC / 期权到期）
    var badges: [Int: MarketBadge] = [:]

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private static let weekdayTitles = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 4) {
            LazyVGrid(columns: Self.columns, spacing: 0) {
                ForEach(Array(Self.weekdayTitles.enumerated()), id: \.offset) { index, title in
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(index >= 5 ? Theme.weekend.opacity(0.9) : Theme.weekdayHeader)
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)
                }
            }

            LazyVGrid(columns: Self.columns, spacing: 2) {
                if leadingBlanks > 0 {
                    // 空白格必须用独立的 id 命名空间：日历格的 id 是日期 Int，1..5 会与 0..<6 撞车，
                    // 撞车后 SwiftUI 会把那几天直接吞掉（网格整体错位）
                    ForEach((0..<leadingBlanks).map { "blank-\($0)" }, id: \.self) { _ in
                        Color.clear.frame(height: DayCell.height)
                    }
                }
                ForEach(cells) { cell in
                    Button {
                        onSelect(cell.day)
                    } label: {
                        DayCell(
                            cell: cell,
                            month: month,
                            isSelected: cell.day == selectedDay,
                            isToday: cell.day == todayDay,
                            marketBadge: badges[cell.day]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
