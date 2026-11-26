import SwiftUI

/// 天气一行：图标 + 温度 + 天况 + 高低温，右侧城市。历史/预报日期没有实时温度时用最高温。
struct WeatherLine: View {
    let day: WeatherDay?
    let isLoading: Bool
    let errorMessage: String?
    let city: String
    /// 显示的是缓存、且这次没刷新成功
    var isStale: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: day?.symbol ?? "cloud.fill")
                .font(.system(size: 13))
                .symbolRenderingMode(.multicolor)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(verbatim: mainValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(day == nil ? Theme.textTertiary : Color.primary)
                .contentTransition(.numericText())

            Text(condition)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

            Text(verbatim: detail)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)

            Spacer(minLength: 6)

            HStack(spacing: 3) {
                Image(systemName: "location.fill")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.accent.opacity(0.8))
                Text(verbatim: day?.locationName ?? city)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.tileFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.tileStroke, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    private var mainValue: String {
        guard let day else { return isLoading ? "…" : "—" }
        if let temperature = day.temperature { return "\(Int(temperature.rounded()))°" }
        if let high = day.high { return "\(Int(high.rounded()))°" }
        return "—"
    }

    private var condition: String {
        guard let day else { return isLoading ? "获取中" : (errorMessage ?? "暂不可用") }
        return day.condition
    }

    private var detail: String {
        guard let day else { return "" }
        var parts: [String] = []
        if let high = day.high, let low = day.low {
            parts.append("最高 \(Int(high.rounded()))° 最低 \(Int(low.rounded()))°")
        }
        if day.isHistory {
            parts.append("实况")
        } else if day.dateKey != WeatherStore.dateKey(for: Date()) {
            parts.append("预报")
        }
        if isStale {
            parts.append("未更新")
        }
        return parts.joined(separator: " · ")
    }
}