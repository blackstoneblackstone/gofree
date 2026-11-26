import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var calendarService: CalendarService

    @State private var cityDraft = ""
    @State private var keyDraft = ""
    @State private var keyStored = false
    @FocusState private var cityFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("显示内容")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 4)

            row(
                title: "美股财报与金融事件",
                subtitle: "财报日、经济数据、FOMC、期权到期、休市",
                isOn: $settings.showsUSMarket
            )
            row(
                title: "日程",
                subtitle: calendarService.isEnabled
                    ? "已开启，显示选中日期的日程"
                    : "开启时会请求日历访问权限",
                isOn: $calendarService.isEnabled
            )
            row(
                title: "假期倒计时",
                subtitle: "标题后显示距下一个法定假期的天数",
                isOn: $settings.showsHolidayCountdown
            )
            row(
                title: "天气",
                subtitle: "当前温度与今日高低温（Open-Meteo，无需 key）",
                isOn: $settings.showsWeather
            )
            if settings.showsWeather {
                HStack(spacing: 8) {
                    Text("城市")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    TextField("北京", text: $cityDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .frame(width: 140)
                        .focused($cityFocused)
                        .onSubmit { commitCity() }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.leading, 0)
                .padding(.bottom, 8)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("外观")
                    .font(.system(size: 12, weight: .medium))
                Text("默认跟随系统，也可以固定成浅色或深色")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                Picker("", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            row(
                title: "黄历详情",
                subtitle: "可展开的 17 项：生肖、星宿、彭祖百忌…",
                isOn: $settings.showsAlmanacDetails
            )

            Divider()
                .padding(.horizontal, 14)
                .padding(.top, 8)

            Text("大模型")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)

            row(
                title: "启用大模型",
                subtitle: "填一个 OpenAI 兼容的模型服务，供解卦等功能调用",
                isOn: $settings.llmEnabled
            )

            if settings.llmEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    labeledField("Base URL", text: $settings.llmBaseURL, placeholder: "https://api.openai.com/v1")
                    labeledField("模型", text: $settings.llmModel, placeholder: "gpt-4o-mini")
                    HStack(spacing: 8) {
                        Text("API Key")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 62, alignment: .leading)
                        SecureField("sk-…", text: $keyDraft)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .onSubmit { saveKey() }
                        Button("保存") { saveKey() }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .pointerCursor()
                        Button(probing ? "测试中…" : "测试") { probe() }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(LLMClient.isConfigured ? Theme.accent : Theme.textTertiary)
                            .disabled(!LLMClient.isConfigured || probing)
                            .pointerCursor()
                        if keyStored {
                            Text("已保存到本机")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    if let probeMessage {
                        Text(probeMessage)
                            .font(.system(size: 9))
                            .foregroundStyle(probeOK ? Theme.jieqi : Theme.festival)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(Text(verbatim: (probeOK ? "连接正常：" : "连接失败：") + probeMessage))
                    }
                    Text("Key 明文存在 ~/Library/Application Support/gofree/secrets.json（仅本人可读），不进钥匙串、不进 plist；DeepSeek、Moonshot 等兼容 /chat/completions 的服务改 Base URL 与模型名即可。现在用到它的是「占一卦」，以后新功能直接复用这套配置。")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            Text("设置会立即生效并被记住，天气数据来自 Open-Meteo。")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 14)
        }
        .frame(width: 340)
        .onAppear {
            cityDraft = settings.weatherCity
            keyDraft = SecretStore.readAPIKey()
            keyStored = !keyDraft.isEmpty
        }
        .onChange(of: cityFocused) { _, focused in
            if !focused { commitCity() }
        }
    }

    /// 「测试连接」的结果：一行绿字或红字
    @State private var probeMessage: String?
    @State private var probeOK = false
    @State private var probing = false

    private func probe() {
        probing = true
        probeMessage = nil
        Task {
            do {
                let reply = try await LLMClient.chat(
                    system: nil,
                    user: "只回复两个字：可用",
                    maxTokens: 16,
                    temperature: 0
                )
                probeOK = true
                probeMessage = "连接正常，模型回复：\(reply.prefix(30))"
            } catch {
                probeOK = false
                probeMessage = (error as? LLMClient.Failure)?.message ?? error.localizedDescription
            }
            probing = false
        }
    }

    private func saveKey() {
        SecretStore.writeAPIKey(keyDraft)
        keyDraft = SecretStore.readAPIKey()
        keyStored = !keyDraft.isEmpty
    }

    private func labeledField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 62, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
        }
    }

    private func commitCity() {
        let trimmed = cityDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? "北京" : trimmed
        guard resolved != settings.weatherCity else { return }
        settings.weatherCity = resolved
    }

    private func row(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}