import SwiftUI

/// 选中日期的 EventKit 日程
struct EventsSection: View {
    var service: CalendarService

    private static let maxEvents = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Hairline().padding(.horizontal, -14)

            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
                Text("日程")
                    .font(.system(size: 11, weight: .semibold))
                Spacer(minLength: 0)
                if service.isRequesting {
                    ProgressView().controlSize(.mini)
                }
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 8)

            if let error = service.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            } else if service.events.isEmpty {
                Text("这一天没有日程")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(service.events.prefix(Self.maxEvents)) { event in
                        HStack(alignment: .top, spacing: 7) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(event.color)
                                .frame(width: 3)
                                .frame(maxHeight: .infinity)
                                .accessibilityHidden(true)
                            Text(event.timeText)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 78, alignment: .leading)
                            Text(event.title)
                                .font(.system(size: 11))
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 14)
                        .accessibilityElement(children: .combine)
                    }
                }
                if service.events.count > Self.maxEvents {
                    Text(verbatim: "还有 \(service.events.count - Self.maxEvents) 项日程")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }
}
