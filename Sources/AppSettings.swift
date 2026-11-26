import AppKit
import Foundation
import Observation

/// 配置中心的数据：各模块显示开关，改动即时落盘
@MainActor
@Observable
final class AppSettings {

    static let shared = AppSettings()

    var showsUSMarket: Bool {
        didSet { defaults.set(showsUSMarket, forKey: Key.usMarket) }
    }

    var showsHolidayCountdown: Bool {
        didSet { defaults.set(showsHolidayCountdown, forKey: Key.holidayCountdown) }
    }

    var showsAlmanacDetails: Bool {
        didSet { defaults.set(showsAlmanacDetails, forKey: Key.almanacDetails) }
    }

    var showsWeather: Bool {
        didSet { defaults.set(showsWeather, forKey: Key.weather) }
    }

    var weatherCity: String {
        didSet { defaults.set(weatherCity, forKey: Key.weatherCity) }
    }

    /// 外观：跟随系统 / 浅色 / 深色
    var appearance: Appearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
            Self.apply(appearance)
        }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case auto, light, dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .auto: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }
    }

    /// 直接把外观挂到 NSApp 上：主题色都是动态 NSColor，会自动跟着切
    /// 起卦方式：高岛略筮（默认）/ 三枚铜钱 / 大衍之数
    var divinationMethod: DivinationMethod {
        didSet { defaults.set(divinationMethod.rawValue, forKey: Key.divinationMethod) }
    }

    /// AI 解读：开关、OpenAI 兼容的 Base URL 与模型名（API Key 存钥匙串，不在这里）
    var llmEnabled: Bool {
        didSet { defaults.set(llmEnabled, forKey: Key.llmEnabled) }
    }

    var llmBaseURL: String {
        didSet { defaults.set(llmBaseURL, forKey: Key.llmBaseURL) }
    }

    var llmModel: String {
        didSet { defaults.set(llmModel, forKey: Key.llmModel) }
    }

    static func apply(_ appearance: Appearance) {
        let app = NSApplication.shared
        switch appearance {
        case .auto: app.appearance = nil
        case .light: app.appearance = NSAppearance(named: .aqua)
        case .dark: app.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private enum Key {
        static let usMarket = "showsUSMarket"
        static let holidayCountdown = "showsHolidayCountdown"
        static let almanacDetails = "showsAlmanacDetails"
        static let weather = "showsWeather"
        static let weatherCity = "weatherCity"
        static let appearance = "appearance"
        static let divinationMethod = "divinationMethod"
        static let llmEnabled = "llmEnabled"
        static let llmBaseURL = "llmBaseURL"
        static let llmModel = "llmModel"
    }

    /// 测试/截图时可以指到别的 suite，保证不会动到用户真实的设置。
    /// 优先级：`GOFREE_DEFAULTS_SUITE` 环境变量 > 标准设置。
    private let defaults: UserDefaults = {
        if let suite = ProcessInfo.processInfo.environment["GOFREE_DEFAULTS_SUITE"], !suite.isEmpty,
           let scoped = UserDefaults(suiteName: suite) {
            return scoped
        }
        return .standard
    }()

    private init() {
        defaults.register(defaults: [
            Key.usMarket: true,
            Key.holidayCountdown: true,
            Key.almanacDetails: true,
            Key.weather: true,
            Key.weatherCity: "北京",
            Key.appearance: Appearance.auto.rawValue,
            Key.divinationMethod: DivinationMethod.takashima.rawValue,
            Key.llmEnabled: false,
            Key.llmBaseURL: "https://api.openai.com/v1",
            Key.llmModel: "gpt-4o-mini",
        ])
        showsUSMarket = defaults.bool(forKey: Key.usMarket)
        showsHolidayCountdown = defaults.bool(forKey: Key.holidayCountdown)
        showsAlmanacDetails = defaults.bool(forKey: Key.almanacDetails)
        showsWeather = defaults.bool(forKey: Key.weather)
        weatherCity = defaults.string(forKey: Key.weatherCity) ?? "北京"
        appearance = Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "")
            ?? .auto
        divinationMethod = DivinationMethod(rawValue: defaults.string(forKey: Key.divinationMethod) ?? "")
            ?? .takashima
        llmEnabled = defaults.bool(forKey: Key.llmEnabled)
        llmBaseURL = defaults.string(forKey: Key.llmBaseURL) ?? "https://api.openai.com/v1"
        llmModel = defaults.string(forKey: Key.llmModel) ?? "gpt-4o-mini"
    }
}