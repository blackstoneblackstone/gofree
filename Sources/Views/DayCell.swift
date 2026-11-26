import SwiftUI

struct DayCell: View {
    static let height: CGFloat = 38

    let cell: CalendarCell
    let month: Int
    let isSelected: Bool
    let isToday: Bool
    var marketBadge: MarketBadge?

    private static let shortWeekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            Text("\(cell.day)")
                .font(.system(size: 15, weight: isSelected || isToday ? .semibold : .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(numberColor)
            Text(cell.label)
                .font(.system(size: 9, weight: cell.kind == .lunar ? .regular : .medium))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(background)
        .overlay(alignment: .topTrailing) { badge }
        .overlay(alignment: .bottomLeading) { marketDot }
        .scaleEffect(hovering && !isSelected ? 1.05 : 1.0)
        .shadow(color: isSelected ? Theme.accent.opacity(0.28) : .clear, radius: 6, y: 2)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: hovering)
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: isSelected)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .pointerCursor()
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(helpText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return Theme.accent }
        if cell.isWeekend { return Theme.weekend }
        return Color.primary.opacity(0.92)
    }

    private var labelColor: Color {
        if isSelected { return Color.white.opacity(0.92) }
        return Theme.labelColor(cell.kind)
    }

    private var helpText: String {
        let weekday = Self.shortWeekdays[max(0, min(6, cell.weekday - 1))]
        var text = "\(month)月\(cell.day)日 \(weekday) · \(cell.label)"
        if cell.isRest { text += " · 休" }
        if cell.isWork { text += " · 班" }
        switch marketBadge {
        case .marketClosed: text += " · 美股休市"
        case .fomc: text += " · FOMC 议息决议"
        case .earnings: text += " · 美股财报日"
        case .quadWitching: text += " · 期权到期（四巫日）"
        case .optionExpiry: text += " · 期权到期"
        case nil: break
        }
        return text
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(isToday && !isSelected ? 0.38 : 0), lineWidth: 1)
            )
    }

    private var fillColor: Color {
        if isSelected { return Theme.accent }
        if hovering { return Theme.hoverFill }
        if isToday { return Theme.accent.opacity(0.09) }
        return .clear
    }

    /// 左下角美股事件圆点：财报 / FOMC 决议 / 期权到期；休市日画空心圈以区分
    @ViewBuilder
    private var marketDot: some View {
        if let badge = marketBadge {
            Group {
                if badge == .marketClosed {
                    Circle()
                        .strokeBorder(isSelected ? Color.white.opacity(0.9)
                                                 : Theme.textSecondary.opacity(0.6),
                                      lineWidth: 1)
                } else {
                    Circle().fill(marketDotColor(badge))
                }
            }
            .frame(width: 4.5, height: 4.5)
            .padding(.leading, 4)
            .padding(.bottom, 4)
        }
    }

    private func marketDotColor(_ badge: MarketBadge) -> Color {
        if isSelected { return Color.white.opacity(0.85) }
        switch badge {
        case .marketClosed: return Theme.textSecondary
        case .fomc: return Theme.festival
        case .earnings: return Theme.earnings
        case .quadWitching: return Color.primary.opacity(0.45)
        case .optionExpiry: return Color.primary.opacity(0.28)
        }
    }

    @ViewBuilder
    private var badge: some View {
        if cell.isRest || cell.isWork {
            let color = cell.isRest ? Theme.rest : Theme.work
            Text(cell.isRest ? "休" : "班")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 10, height: 10)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.26) : color)
                )
                .padding(.trailing, 3)
                .padding(.top, 2)
        }
    }
}