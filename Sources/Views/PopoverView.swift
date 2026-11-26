import SwiftUI

struct PopoverView: View {
    var store: AlmanacStore
    var calendarService: CalendarService
    var onQuit: () -> Void

    @Binding var showsMore: Bool

    @State private var marketStore = MarketStore()
    private let settings = AppSettings.shared
    private let restManager = RestReminderManager.shared
    @State private var weatherStore = WeatherStore()


    static let width: CGFloat = 384


    var body: some View {
        VStack(spacing: 0) {
            header

            MonthGridView(
                cells: store.cells,
                leadingBlanks: store.leadingBlanks,
                selectedDay: store.selectedDay,
                todayDay: store.todayDay,
                month: store.key.month,
                onSelect: { store.select(day: $0) },
                badges: settings.showsUSMarket
                    ? marketStore.badges(year: store.key.year, month: store.key.month)
                    : [:]
            )
            .padding(.horizontal, 14)

            if settings.showsWeather {
                WeatherLine(
                    day: weatherStore.day,
                    isLoading: weatherStore.isLoading,
                    errorMessage: weatherStore.errorMessage,
                    city: settings.weatherCity,
                    isStale: weatherStore.isStale
                )
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }

            if settings.restReminderEnabled || restManager.activeSession != nil {
                RestLine(manager: restManager, onOpen: { RestWindow.open() })
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }

            ActionBar(
                onDivination: { DivinationWindow.open() },
                onRest: { RestWindow.open() },
                onExpanded: { ExpandedWindow.open(store: store, calendarService: calendarService) },
                onRefresh: { store.reload() },
                onSettings: { SettingsWindow.open(calendarService: calendarService) }
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)

            if let detail = store.detail, showsDetailCard(detail) {
                DayDetailView(
                    detail: detail,
                    showsMore: $showsMore,
                    market: settings.showsUSMarket ? marketStore.day : MarketDay(),
                    marketLoading: settings.showsUSMarket && marketStore.isLoading,
                    showsAlmanac: settings.showsAlmanacDetails
                )
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }

            if calendarService.isEnabled {
                EventsSection(service: calendarService)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
            }

            footer
        }
        .frame(width: Self.width)
        .background(
            ZStack {
                VisualEffectBackground(material: .popover)
                Theme.surface
            }
        )
        .onAppear {
            refreshEvents()
            loadMarket()
            loadWeather()
        }
        .onChange(of: store.selectedDay) { _, _ in
            showsMore = false
            refreshEvents()
            loadMarket()
            loadWeather()
        }
        .onChange(of: store.key) { _, _ in
            showsMore = false
            refreshEvents()
            loadMarket()
            loadWeather()
        }
        .onChange(of: calendarService.isEnabled) { _, _ in
            refreshEvents()
        }
        .onChange(of: settings.showsUSMarket) { _, _ in
            loadMarket()
        }
        .onChange(of: settings.weatherCity) { _, _ in
            loadWeather()
        }
        .onChange(of: settings.showsWeather) { _, _ in
            loadWeather()
        }
        .onChange(of: calendarService.isRequesting) { _, requesting in
            if !requesting { refreshEvents() }     // 授权流程结束，按当前选中日重取
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24, height: 24)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Theme.accent.opacity(0.12))
                    }
                    .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(store.monthName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .contentTransition(.numericText())
                    Text(store.yearName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .contentTransition(.numericText())
                }

                if settings.showsHolidayCountdown, let countdown = store.holidayCountdown {
                    HStack(spacing: 3) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.festival)
                        Text(countdown)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        Capsule(style: .continuous)
                            .fill(Theme.tileFill)
                    }
                }
            }

            Spacer(minLength: 6)

            monthNav

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    store.goToday()
                }
            } label: {
                Text("今天")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.isTodaySelected ? Theme.textTertiary : Theme.accent)
                    .frame(height: 24)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(store.isTodaySelected ? Color.clear : Theme.accent.opacity(0.12))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .help("回到今天")

            menuButton
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var monthNav: some View {
        HStack(spacing: 2) {
            HoverIconButton(systemName: "chevron.left", size: 11, width: 26, height: 24, help: "上一月") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    store.step(-1)
                }
            }
            HoverIconButton(systemName: "chevron.right", size: 11, width: 26, height: 24, help: "下一月") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    store.step(1)
                }
            }
        }
    }

    private var menuButton: some View {
        Menu {
            Button("关于 gofree") { NSApplication.shared.orderFrontStandardAboutPanel(nil) }
            Divider()
            Button("退出 gofree") { onQuit() }
        } label: {
            HoverIconButtonLabel(systemName: "ellipsis", title: "更多操作", size: 11, width: 26, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26)
        .help("更多操作")
        .accessibilityLabel("更多操作")
    }

    // MARK: - 页脚

    private var footer: some View {
        HStack(spacing: 6) {
            Text(store.footnote)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .font(.system(size: 10))
        .foregroundStyle(Theme.textTertiary)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func refreshEvents() {
        guard calendarService.isEnabled else { return }
        let key = store.key
        let date = AlmanacEngine.makeDate(year: key.year, month: key.month, day: store.selectedDay)
        calendarService.refresh(for: date)
    }

    private func loadWeather() {
        guard settings.showsWeather else { return }
        let key = store.key
        let date = AlmanacEngine.makeDate(year: key.year, month: key.month, day: store.selectedDay)
        weatherStore.load(city: settings.weatherCity, date: date)
    }

    /// 卡片里一个可显示的内容都没有时就不画卡片
    private func showsDetailCard(_ detail: DayDetailModel) -> Bool {
        !detail.festivals.isEmpty || settings.showsAlmanacDetails || settings.showsUSMarket
    }

    private func loadMarket() {
        guard settings.showsUSMarket else { return }
        let key = store.key
        let date = AlmanacEngine.makeDate(year: key.year, month: key.month, day: store.selectedDay)
        marketStore.load(for: date)
    }
}
