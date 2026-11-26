import SwiftUI

struct ExpandedCalendarView: View {
    var store: AlmanacStore
    var calendarService: CalendarService
    private let settings = AppSettings.shared
    @State private var marketStore = MarketStore()

    static let width: CGFloat = 716

    private var rightKey: MonthKey { store.key.offset(by: 1) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)

            HStack(alignment: .top, spacing: 16) {
                monthColumn(store.key)
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 0.5)
                    .padding(.horizontal, 2)
                monthColumn(rightKey)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .frame(width: Self.width)
        .background(
            ZStack {
                VisualEffectBackground(material: .windowBackground)
                Theme.surface
            }
        )
        .onAppear { loadMarket() }
        .onChange(of: store.key) { _, _ in loadMarket() }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(store.key.year)年\(store.key.month)月 – \(rightKey.year)年\(rightKey.month)月")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText())
            Spacer(minLength: 8)
            monthNav
            Button {
                store.goToday()
            } label: {
                Text("今天")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.isTodaySelected ? Theme.textTertiary : Theme.accent)
                    .frame(height: 24)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(store.isTodaySelected ? Color.clear : Theme.accent.opacity(0.1))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .help("回到今天")
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var monthNav: some View {
        HStack(spacing: 2) {
            HoverIconButton(systemName: "chevron.left", size: 11, width: 26, height: 24, help: "上一个月") {
                store.step(-1)
            }
            HoverIconButton(systemName: "chevron.right", size: 11, width: 26, height: 24, help: "下一个月") {
                store.step(1)
            }
        }
    }

    // MARK: - 月列

    private func monthColumn(_ key: MonthKey) -> some View {
        // 走 AlmanacStore 的缓存，避免每次 body 重算整月
        let data = store.cachedMonth(for: key)
        let isCurrent = key == store.key
        let isThisMonth = key == Date().monthKey

        return VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(key.month)月")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
            }

            MonthGridView(
                cells: data.days.map(CalendarCell.init),
                leadingBlanks: data.firstWeekdayOffset,
                selectedDay: isCurrent ? store.selectedDay : -1,
                todayDay: isThisMonth ? Date().dayNumber : nil,
                month: key.month,
                onSelect: { day in
                    if !isCurrent { store.go(to: key) }
                    store.select(day: day)
                },
                badges: settings.showsUSMarket
                    ? marketStore.badges(year: key.year, month: key.month)
                    : [:]
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func loadMarket() {
        guard settings.showsUSMarket else { return }
        let next = rightKey
        marketStore.load(for: AlmanacEngine.makeDate(year: store.key.year, month: store.key.month, day: 1))
        marketStore.load(for: AlmanacEngine.makeDate(year: next.year, month: next.month, day: 1))
    }
}