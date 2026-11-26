import EventKit
import Observation
import SwiftUI

struct EventItem: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color

    var timeText: String {
        if isAllDay { return "全天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }
}

/// EventKit 日程（可选功能，默认关闭，需用户在菜单里手动开启并授权）。
@MainActor
@Observable
final class CalendarService {

    static let shared = CalendarService()

    static let enabledDefaultsKey = "showsCalendarEvents"

    private(set) var events: [EventItem] = []
    private(set) var isRequesting = false
    private(set) var errorMessage: String?

    /// 开关直接绑定到用户的设置（Setter 里完成落盘与授权）
    var isEnabled: Bool {
        get { enabled }
        set {
            guard newValue != enabled else { return }
            newValue ? enable() : disable()
        }
    }

    private var enabled: Bool

    private let store = EKEventStore()

    init() {
        enabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
    }

    private var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func enable() {
        enabled = true
        UserDefaults.standard.set(true, forKey: Self.enabledDefaultsKey)
        requestAccessThenReload()
    }

    func disable() {
        enabled = false
        UserDefaults.standard.set(false, forKey: Self.enabledDefaultsKey)
        events = []
        errorMessage = nil
    }

    func refresh(for date: Date) {
        guard isEnabled else { return }
        guard hasAccess else {
            events = []
            errorMessage = "未获得日历访问权限"
            return
        }
        loadEvents(for: date)
    }

    private func requestAccessThenReload() {
        isRequesting = true
        errorMessage = nil
        let completion: (Bool, Error?) -> Void = { [weak self] granted, error in
            Task { @MainActor in
                guard let self else { return }
                self.isRequesting = false
                if let error {
                    self.errorMessage = error.localizedDescription
                } else if !granted {
                    self.errorMessage = "未获得日历访问权限"
                }
                // 授权成功后的刷新交给视图：它按「当前选中的那天」取事件，
                // 这里直接取今天会在选中别的日期时显示错的日子。
            }
        }
        store.requestFullAccessToEvents(completion: completion)
    }

    private func loadEvents(for date: Date) {
        let calendar = Calendar.gregorianMondayFirst
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let items = store.events(matching: predicate)
            .map { event in
                EventItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: (event.title?.isEmpty == false ? event.title : nil) ?? "（无标题）",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    color: event.calendar.map { Color(nsColor: $0.color) } ?? Theme.accent
                )
            }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.start < rhs.start
            }

        events = items
        errorMessage = nil
    }
}