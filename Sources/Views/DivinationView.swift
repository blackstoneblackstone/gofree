import SwiftUI

struct DivinationView: View {
    static let width: CGFloat = 760
    /// 结果卡左栏（结论印鉴 + 卦象 + 往占）宽度（8pt 栅格）
    private static let leftPaneWidth: CGFloat = 248
    /// 结果卡总高：右栏内容超出就在卡内滚动，窗口尺寸保持稳定
    private static let resultCardHeight: CGFloat = 488

    @State private var question: String
    @State private var result: DivinationResult?
    @State private var duplicate: DivinationRecord?
    @State private var similar: DivinationJournal.SimilarMatch?
    @State private var showsTuan = false
    @State private var showsTakashima = false
    @State private var showsHistory = false
    /// 准备引导阶段：用户点「起卦」后先进入此阶段，动画引导走完高岛筮仪三步，再由用户亲点「准备好了，起卦」
    @State private var preparingQuestion: String?
    @State private var prepStep: Int?
    @State private var prepReady = false
    /// 起卦过程：staged 有值就表示正在成爻，六爻走完才交给 result
    @State private var staged: DivinationResult?
    @State private var stagedLines = 0
    @State private var rollingIndex: Int?
    @State private var coinFaces: [Bool] = [false, false, false]
    @State private var yarrowCounts: [Int] = []
    /// 铜钱是否已经落定（摇的过程中随机面不能配合断语一起显示）
    @State private var coinsSettled = false
    @State private var castTask: Task<Void, Never>?
    @State private var interpreter = DivinationInterpreter()
    @FocusState private var questionFocused: Bool
    @Namespace private var methodTabNS
    @Bindable private var settings = AppSettings.shared
    private let journal = DivinationJournal.shared
    /// 内容高度变化时通知窗口（结果出来后窗口要跟着变高）
    var onSizeChange: ((CGSize) -> Void)?
    /// 截图时注入的往占记录（不写用户数据）
    var previewRecords: [DivinationRecord]?

    /// 截图与自检时可以直接注入结果。
    init(
        previewQuestion: String = "",
        previewResult: DivinationResult? = nil,
        previewRecords: [DivinationRecord]? = nil,
        previewExpandedHistory: Bool = false,
        previewShowsTuan: Bool = false,
        previewShowsTakashima: Bool = false,
        previewCastProgress: Int? = nil,
        previewLLMText: String? = nil,
        previewLLMError: String? = nil,
        onSizeChange: ((CGSize) -> Void)? = nil
    ) {
        _question = State(initialValue: previewQuestion)
        _result = State(initialValue: previewResult)
        _showsHistory = State(initialValue: previewExpandedHistory)
        _showsTuan = State(initialValue: previewShowsTuan)
        _showsTakashima = State(initialValue: previewShowsTakashima)
        // 截图时若注入的记录里就有同一个问题，直接把「一事不二占」的提示摆出来
        _duplicate = State(initialValue: previewRecords?.first {
            DivinationJournal.normalize($0.question) == DivinationJournal.normalize(previewQuestion)
        })
        _similar = State(initialValue: previewRecords.flatMap { records -> DivinationJournal.SimilarMatch? in
            let key = DivinationJournal.normalize(previewQuestion)
            guard !key.isEmpty else { return nil }
            return records.first { record in
                let other = DivinationJournal.normalize(record.question)
                guard other != key else { return false }
                return DivinationJournal.similarity(key, other) >= 0.8
                    || DivinationJournal.contained(key, other)
            }.map {
                DivinationJournal.SimilarMatch(
                    record: $0,
                    score: DivinationJournal.similarity(key, DivinationJournal.normalize($0.question)),
                    contained: DivinationJournal.similarity(key, DivinationJournal.normalize($0.question)) < 0.8
                )
            }
        })
        // 截图起卦过程：冻结在第 n 爻刚落成的瞬间
        if let previewCastProgress, let previewResult {
            _result = State(initialValue: nil)
            _staged = State(initialValue: previewResult)
            _stagedLines = State(initialValue: previewCastProgress)
            _rollingIndex = State(initialValue: previewCastProgress < 6 ? previewCastProgress : nil)
            let next = previewResult.lines.indices.contains(previewCastProgress) ? previewResult.lines[previewCastProgress].value : 9
            _coinFaces = State(initialValue: Self.faces(for: next))
            _yarrowCounts = State(initialValue: DivinationEngine.yarrowCounts(for: next))
            _coinsSettled = State(initialValue: true)
        }
        self.previewRecords = previewRecords
        self.onSizeChange = onSizeChange
        if let previewLLMText {
            _interpreter = State(initialValue: DivinationInterpreter(previewText: previewLLMText))
        }
        if let previewLLMError {
            _interpreter = State(initialValue: DivinationInterpreter(previewFailure: previewLLMError))
        }
    }

    /// 往占列表数据源：正常走记录簿，截图时用注入值。
    private var records: [DivinationRecord] { previewRecords ?? journal.records }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            inputRow
            methodPicker
            if let duplicate {
                duplicateNotice(duplicate)
                    .padding(.top, 8)
            } else if let similar {
                similarNotice(similar)
                    .padding(.top, 8)
            }
            Group {
                if let asked = preparingQuestion {
                    preparationCard(for: asked)
                } else if let staged {
                    castingCard(staged)
                } else if let result {
                    resultCard(result)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        emptyHint
                        historySection
                    }
                }
            }
            .padding(.top, 16)
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(width: Self.width)
        .tint(Theme.divineAccent)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            onSizeChange?(size)
        }
        .background(Theme.divineSurface)
        .onDisappear {
            castTask?.cancel()
            castTask = nil
            interpreter.cancel()
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.divineAccent)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.divineHighlight)
                }
            Text("占一事")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.divineInk)
            HStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 9))
                Text("高岛易断")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.divineAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(Theme.divineHighlight)
            }
            Spacer(minLength: 0)
            if result != nil || staged != nil || preparingQuestion != nil {
                Button {
                    startNewDivination()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                        Text("新占一卦")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.divineAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.divineHighlight)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.divineAccent.opacity(0.22), lineWidth: 0.6)
                    }
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: result != nil || staged != nil || preparingQuestion != nil)
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 12))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(questionFocused ? Theme.divineAccent : Theme.divineInkTertiary)
                TextField("写下要问的具体一件事，例如「这周要不要加仓」", text: $question)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.divineInk)
                    .focused($questionFocused)
                    .onSubmit { cast() }
                if !question.isEmpty && staged == nil {
                    Button {
                        question = ""
                        duplicate = nil
                        similar = nil
                        questionFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.divineInkTertiary.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .accessibilityLabel("清空问题")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.divineCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        questionFocused ? Theme.divineAccent.opacity(0.65) : Theme.divineCardStroke,
                        lineWidth: questionFocused ? 1.25 : 0.75
                    )
            }
            .animation(.easeOut(duration: 0.16), value: questionFocused)

            Button { cast() } label: {
                HStack(spacing: 5) {
                    Image(systemName: (staged != nil || preparingQuestion != nil) ? "hourglass" : "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                    Text(preparingQuestion != nil ? "准备中" : (staged != nil ? "起卦中" : (result == nil ? "起卦" : "重占")))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.divineAccent)
                        .shadow(color: Theme.divineAccent.opacity(0.28), radius: 6, y: 2)
                }
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .disabled(staged != nil || preparingQuestion != nil)
        }
        .padding(.top, 12)
    }

    private func methodIcon(_ method: DivinationMethod) -> String {
        switch method {
        case .takashima: return "circle.hexagongrid"
        case .coins: return "centsign.circle"
        case .yarrow: return "lines.measurement.horizontal"
        }
    }

    /// 起卦方式：高岛略筮 / 三枚铜钱 / 大衍之数，带平滑滑动胶囊指示器与图标
    private var methodPicker: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(DivinationMethod.allCases) { method in
                    let selected = settings.divinationMethod == method
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            settings.divinationMethod = method
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: methodIcon(method))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(selected ? Theme.divineAccent : Theme.divineInkTertiary)
                            Text(method.title)
                                .font(.system(size: 11, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? Theme.divineInk : Theme.divineInkSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.divineCard)
                                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "methodPill", in: methodTabNS)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.divineInset)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.divineCardStroke, lineWidth: 0.5)
            }

            Text(settings.divinationMethod.caption)
                .font(.system(size: 11))
                .foregroundStyle(Theme.divineInkTertiary)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    /// 起卦前步骤（白话版高岛起卦准备），空态常驻提示，起卦时逐项引导。
    private var ritualSteps: [(numeral: String, icon: String, title: String, detail: String)] {
        let third: (String, String) = {
            switch settings.divinationMethod {
            case .takashima:
                return ("默念后起卦", "静默几秒把问题在心里过一遍，觉得准备好了就点按钮，系统按高岛法三变成卦。")
            case .coins:
                return ("默念后掷钱", "心里默念你想问的事，静下来后点按钮，模拟三枚铜钱连掷六次成卦。")
            case .yarrow:
                return ("默念后演卦", "心里默念你想问的事，静下来后点按钮，按古法四十九策十八变成卦。")
            }
        }()
        return [
            ("1", "drop.fill", "先静一静心", "暂离手头的杂事，深吸一口气，放空念头，不先入为主。"),
            ("2", "scope", "想清这一件事", "在上面写下最让你拿不准的一件事，心里默念清楚；同一件事不反复占。"),
            ("3", "hands.sparkles.fill", third.0, third.1),
        ]
    }

    private var currentDivinerPhase: DivinerPhase {
        if let step = prepStep {
            switch step {
            case 0: return .cleanse
            case 1: return .focus
            default: return .pray
            }
        }
        return staged != nil ? .casting : .idle
    }

    private var emptyHint: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.divineAccent)
                    Text("起卦前准备")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.divineInk)
                    Spacer(minLength: 0)
                    Text("心静下来再开始")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.divineInkTertiary)
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ritualSteps, id: \.numeral) { step in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: step.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Theme.divineAccent)
                                .frame(width: 24, height: 24)
                                .background {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Theme.divineHighlight)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(step.numeral) · \(step.title)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.divineInk)
                                Text(step.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.divineInkSecondary)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DivinerSceneView(phase: .idle)
                .frame(width: 184, height: 184)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.divineInset)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.divineCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.divineCardStroke, lineWidth: 0.75)
        }
    }

    // MARK: 起卦前准备引导

    /// 单一主视觉居中舞台：顶部三步进度条 → 中央大尺寸 3D 星环与四十九策光束 → 醒目引导文案 → 居中「我准备好了，开始起卦」主按钮。
    private func preparationCard(for asked: String) -> some View {
        let current = prepStep ?? 2
        return VStack(spacing: 16) {
            // 顶部三步仪节横向指示器
            HStack(spacing: 8) {
                ForEach(Array(ritualSteps.enumerated()), id: \.offset) { idx, step in
                    let isDone = prepReady || idx < current
                    let isActive = !prepReady && idx == current
                    HStack(spacing: 5) {
                        Image(systemName: isDone ? "checkmark.circle.fill" : step.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isDone ? Theme.jieqi : (isActive ? Theme.divineAccent : Theme.divineInkTertiary))
                        Text(step.title)
                            .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(isActive ? Theme.divineInk : (isDone ? Theme.divineInkSecondary : Theme.divineInkTertiary))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule(style: .continuous)
                            .fill(isActive ? Theme.divineHighlight : Theme.divineInset.opacity(0.75))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(isActive ? Theme.divineAccent.opacity(0.35) : .clear, lineWidth: 0.75)
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)

                    if idx < 2 {
                        Rectangle()
                            .fill(isDone ? Theme.jieqi.opacity(0.55) : Theme.divineHairline)
                            .frame(width: 24, height: 1.5)
                            .animation(.easeInOut(duration: 0.35), value: current)
                    }
                }
            }

            // 中央主视觉：放大到 210×210 的 3D 透视星环 + 四十九策呼吸光束
            DivinerSceneView(phase: currentDivinerPhase, showsBadge: false)
                .frame(width: 210, height: 210)

            // 居中引导标题 + 所问事项
            VStack(spacing: 6) {
                Text(prepGuideTitle(step: current, ready: prepReady))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.divineInk)
                    .contentTransition(.numericText())
                Text(prepGuideBody(step: current, ready: prepReady, question: asked))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.divineInkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 440)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 底部居中主操作按钮
            HStack(spacing: 12) {
                Button {
                    beginActualCast()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: prepReady ? "wand.and.stars" : "forward.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(prepReady ? "我准备好了，开始起卦" : "跳过引导，直接起卦")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(prepReady ? Color.white : Theme.divineInkSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(prepReady ? Theme.divineAccent : Theme.divineInset)
                            .shadow(color: prepReady ? Theme.divineAccent.opacity(0.36) : .clear, radius: 12, y: 3)
                    }
                    .scaleEffect(prepReady ? 1.03 : 1.0)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: prepReady)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.divineCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.divineCardStroke, lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.05), radius: 12, y: 2)
    }

    private func prepGuideTitle(step: Int, ready: Bool) -> String {
        if ready { return "准备好了，可以起卦" }
        switch step {
        case 0: return "1 · 先静一静心"
        case 1: return "2 · 专注你想问的事"
        default: return "3 · 静默片刻，准备起卦"
        }
    }

    private func prepGuideBody(step: Int, ready: Bool, question: String) -> String {
        if ready {
            return "心里想着「\(question)」，觉得时机正好时，点下面按钮立刻开始起卦。"
        }
        switch step {
        case 0:
            return "深吸一口气，放空手头的杂念，也别急着预设想要的结果。"
        case 1:
            return "把注意力收回到「\(question)」上，在心里清清楚楚默念一遍。"
        default:
            return settings.divinationMethod == .coins
                ? "把「\(question)」在心里再过一遍，静下来后就可以落钱成卦。"
                : "把「\(question)」在心里再过一遍，等觉得心定下来了就可以开始起卦。"
        }
    }

    // MARK: 起卦过程

    private func castingCard(_ made: DivinationResult) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(prepStep != nil ? "起卦前" : "起卦中")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.divineInk)
                    Text(castingStepText(made))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.divineInkTertiary)
                }
                if let current = prepStep {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(ritualSteps.enumerated()), id: \.offset) { idx, step in
                            let isActive = idx == current
                            let isDone = idx < current
                            HStack(spacing: 8) {
                                Image(systemName: isDone ? "checkmark.circle.fill" : (isActive ? "circle.inset.filled" : "circle"))
                                    .font(.system(size: 12))
                                    .foregroundStyle(isActive || isDone ? Theme.divineAccent : Theme.divineInkTertiary.opacity(0.6))
                                Text("\(step.numeral) · \(step.title)")
                                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                                    .foregroundStyle(isActive ? Theme.divineInk : Theme.divineInkSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.divineInset)
                    }
                } else {
                    CastingBoard(
                        method: settings.divinationMethod,
                        values: made.lines.map(\.value),
                        revealed: stagedLines,
                        rollingIndex: rollingIndex,
                        coinFaces: coinFaces,
                        yarrowCounts: yarrowCounts
                    )
                }
            }
            .padding(20)
            .frame(width: Self.leftPaneWidth, alignment: .leading)

            Rectangle()
                .fill(Theme.divineHairline)
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button("跳过") { finishCasting() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.divineAccent)
                        .pointerCursor()
                }
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(castingCaption(made))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.divineInk)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(castingSideNote)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.divineInkSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    DivinerSceneView(phase: currentDivinerPhase)
                        .frame(width: 176, height: 176)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.divineInset)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.divineCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.divineCardStroke, lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.05), radius: 12, y: 2)
    }

    /// 起卦过程右栏的常驻说明，免得右半边只有一行字显得空
    private var castingSideNote: String {
        switch settings.divinationMethod {
        case .takashima:
            return "《高岛易断》略筮法：五十策用四十九，分二挂一。第一变揲八定下卦，第二变揲八定上卦，第三变揲六定一动爻。"
        case .coins:
            return "三枚铜钱掷六次：两背为阳、两字为阴，三背为老阳（动）、三字为老阴（动）。动爻决定取哪条卦辞。"
        case .yarrow:
            return "大衍之数五十，其用四十九：三变成一爻、十八变成一卦。策数分二挂一，揲四归奇。"
        }
    }

    private func castingStepText(_ made: DivinationResult) -> String {
        if let step = prepStep {
            return "高岛筮仪 \(step + 1)/3"
        }
        if let index = rollingIndex { return "第 \(index + 1) 爻" }
        return stagedLines > 0 ? "已成 \(stagedLines) 爻" : "静心，开始"
    }

    private func castingCaption(_ made: DivinationResult) -> String {
        if let step = prepStep {
            switch step {
            case 0:
                return "净手澄心：暂缓杂念，令气息平稳。"
            case 1:
                return "专念所问：心中只念「\(made.question)」这一件事。"
            default:
                return settings.divinationMethod == .coins
                    ? "掌钱默祷：三枚铜钱合握掌中，默祷片刻，准备起卦。"
                    : "合策默祷：五十策去一存太极，合握四十九策默祷，即将分二起卦。"
            }
        }
        guard let index = rollingIndex, made.lines.indices.contains(index) else {
            return "六爻成卦后，以《周易》与《高岛易断》断吉凶。"
        }
        let line = made.lines[index]
        switch settings.divinationMethod {
        case .takashima:
            let phase = index < 3
                ? "第一变·下卦（\(made.primary.lower.rawValue)）"
                : "第二变·上卦（\(made.primary.upper.rawValue)）"
            let moving = line.isChanging ? " · 第三变定动爻" : ""
            return "\(phase) → \(DivinationResult.positionName(index + 1))：\(line.label)\(moving)"
        case .coins:
            let position = DivinationResult.positionName(index + 1)
            guard coinsSettled else { return "\(position)：摇钱中…" }
            let faces = coinFaces.map { $0 ? "背" : "字" }.joined(separator: " ")
            return "\(position)：\(faces) → \(line.label)（\(line.value)）"
        case .yarrow:
            let trail = (["49"] + yarrowCounts.map(String.init)).joined(separator: " → ")
            return "\(DivinationResult.positionName(index + 1))：三变 \(trail) → \(line.label)（\(line.value)）"
        }
    }

    // MARK: AI 解读

    /// AI 解卦：放在结果卡最前面，用暖调底色托起正文，避免与下方古文混作一团。
    @ViewBuilder
    private func aiSection(_ result: DivinationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.divineAccent)
                Text("AI 解卦")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.divineInk)
                if result.question != "此事" {
                    Text("· \(result.question)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.divineInkTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
                if isAIReady {
                    if case .loading = interpreter.phase {
                        Button("取消") { interpreter.cancel() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.divineInkTertiary)
                            .pointerCursor()
                    } else {
                        Button(aiButtonTitle) { interpretWithCurrentQuestion(result) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.divineAccent)
                            .pointerCursor()
                    }
                } else {
                    Button("去设置") { SettingsWindow.open() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.divineAccent)
                        .pointerCursor()
                }
            }
            if isAIReady {
                aiContent
            } else {
                Text(aiUnavailableHint)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.divineInkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.divineHighlight)
        }
    }

    private var isAIReady: Bool {
        settings.llmEnabled && LLMClient.isConfigured
    }

    private var aiUnavailableHint: String {
        if !settings.llmEnabled {
            return "大模型没开。到设置 → 大模型里打开开关，填 Base URL、模型名和 API Key，就会在这里自动解卦。"
        }
        return "还没填 API Key。到设置 → 大模型里填上，点「测试」看到绿字就通了。"
    }

    private var aiButtonTitle: String {
        if case .done = interpreter.phase { return "重新解读" }
        return "解读"
    }

    @ViewBuilder
    private var aiContent: some View {
        switch interpreter.phase {
        case .idle:
            Text("起卦后自动结合《高岛易断》生成白话解答；也可以点「解读」重新生成。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.divineInkSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在结合《高岛易断》为你解卦…")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.divineInkSecondary)
            }
            .padding(.vertical, 4)
        case let .done(text):
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.divineInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        case let .failed(message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.festival)
                    .fixedSize(horizontal: false, vertical: true)
                Text("到设置里检查 Base URL、模型名和 API Key。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.divineInkTertiary)
            }
        }
    }

    // MARK: 结果

    /// 横向大卡：左栏是结论印鉴、卦象与往占；右栏是 AI 解卦、高岛易断、周易原文与依据。
    private func resultCard(_ result: DivinationResult) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                verdictHeader(result)
                YaoStack(lines: result.lines, titles: lineTitles(result.primary))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.divineInset)
                    }
                if !self.records.isEmpty {
                    Rectangle()
                        .fill(Theme.divineHairline)
                        .frame(height: 1)
                        .padding(.top, 2)
                    historySection
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(width: Self.leftPaneWidth, alignment: .leading)

            Rectangle()
                .fill(Theme.divineHairline)
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    aiSection(result)
                    takashimaSection(result)
                    Rectangle()
                        .fill(Theme.divineHairline)
                        .frame(height: 1)
                    quotes(result.quotes)
                    essence(result)
                    Rectangle()
                        .fill(Theme.divineHairline)
                        .frame(height: 1)
                    reasons(result.reasons)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [Theme.divineCard.opacity(0), Theme.divineCard],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 24)
                .allowsHitTesting(false)
            }
        }
        .frame(height: Self.resultCardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.divineCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.divineCardStroke, lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.05), radius: 12, y: 2)
    }

    /// 签名细节：左侧印鉴式结论 + 衬线卦名。
    /// 开启 AI 解卦后，左栏结论与 AI 研判保持一致，避免程序字面打分与语义解读打架。
    private func verdictHeader(_ result: DivinationResult) -> some View {
        let isLoadingAI: Bool = {
            if case .loading = interpreter.phase { return true }
            return false
        }()
        let activeLevel = interpreter.interpretedLevel ?? result.verdict.level
        let badgeText = isLoadingAI ? "研判中" : activeLevel.rawValue
        let badgeColor = isLoadingAI ? Theme.divineInkSecondary : activeLevel.color
        let subtitle: String = {
            if isLoadingAI {
                return "正在结合你的问题与《高岛易断》研判…"
            }
            if interpreter.interpretedLevel != nil {
                return "AI 结合所问事项与《高岛易断》研判。"
            }
            return result.verdict.summary
        }()

        let badgeIcon: String = {
            if isLoadingAI { return "hourglass" }
            switch activeLevel {
            case .go: return "checkmark.seal.fill"
            case .cautious: return "exclamationmark.triangle.fill"
            case .avoid: return "xmark.seal.fill"
            }
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    Text(badgeText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(badgeColor.opacity(0.12))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(badgeColor.opacity(0.28), lineWidth: 0.75)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: badgeText)

                Text(result.changingDescription ?? "六爻皆静")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.divineInkTertiary)
            }
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Theme.divineInkSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(result.primary.symbol) \(result.primary.name)")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.divineInk)
                    Text(result.primary.fullName)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.divineInkTertiary)
                }
                if let changed = result.changed, changed.number != result.primary.number {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("之")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.divineInkTertiary)
                        Text("\(changed.symbol) \(changed.name)")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.divineInkSecondary)
                        Text(changed.fullName)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.divineInkTertiary)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    /// 大象原文与可展开的《彖传》
    private func essence(_ result: DivinationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !result.primary.image.isEmpty {
                Text("大象 · \(result.primary.image)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.divineInkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                withAnimation(.easeOut(duration: 0.14)) { showsTuan.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(showsTuan ? "收起《彖传》" : "看《彖传》")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(showsTuan ? 0 : -90))
                }
                .foregroundStyle(Theme.divineAccent)
            }
            .buttonStyle(.plain)
            .pointerCursor()
            if showsTuan {
                Text(result.primary.tuan)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.divineInkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 高岛易断：直接亮出切题【占】断语；点开可看完整卦断、动爻断例（断曰）与之卦卦断。
    @ViewBuilder
    private func takashimaSection(_ result: DivinationResult) -> some View {
        let highlights = result.takashimaHighlights
        let entries = result.takashimaEntries
        if !highlights.isEmpty || !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.divineAccent)
                    Text("高岛易断")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.divineInk)
                    Text("切题取断")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.divineInkTertiary)
                }

                if !highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(highlights) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.source) · \(item.topic)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(item.isPrimary ? Theme.divineAccent : Theme.divineInkTertiary)
                                Text(item.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(item.isPrimary ? Theme.divineInk : Theme.divineInkSecondary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                if !entries.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.14)) { showsTakashima.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showsTakashima ? "收起高岛全断与占例" : "展开高岛全断与占例")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .rotationEffect(.degrees(showsTakashima ? 0 : -90))
                        }
                        .foregroundStyle(Theme.divineAccent)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .accessibilityHint("展开高岛嘉右卫门《高岛易断》的完整断语与占例原文")

                    if showsTakashima {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(entries, id: \.self) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Theme.divineInkTertiary)
                                    Text(entry.text)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.divineInkSecondary)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.divineInset)
                        }
                    }
                }
            }
        }
    }

    /// 疑似同一件事的提示：措辞接近或问法互相包含
    private func similarNotice(_ match: DivinationJournal.SimilarMatch) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.earnings)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("好像问过：「\(match.record.question)」")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.divineInk)
                    .lineLimit(2)
                Text(match.contained
                     ? "\(Self.dayText(match.record.askedAt)) 问过一件很像的事，是同一件吗？"
                     : "\(Self.dayText(match.record.askedAt)) 问过，措辞相近（\(Int((match.score * 100).rounded()))%）")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.divineInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("仍然起卦") { cast(force: true) }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.divineAccent)
                .pointerCursor()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.earnings.opacity(0.1))
        }
    }

    /// 一事不二占的提示
    private func duplicateNotice(_ record: DivinationRecord) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.earnings)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("一事不二占：这件事 \(Self.dayText(record.askedAt)) 已经问过")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.divineInk)
                Text("换个更具体的问法；真要再起一卦，点「仍然起卦」。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.divineInkSecondary)
            }
            Spacer(minLength: 8)
            Button("仍然起卦") { cast(force: true) }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.divineAccent)
                .pointerCursor()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.earnings.opacity(0.1))
        }
    }

    /// 往占记录
    @ViewBuilder
    private var historySection: some View {
        let records = Array(self.records.prefix(20))
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeOut(duration: 0.14)) { showsHistory.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.divineAccent.opacity(0.85))
                        Text("往占 \(self.records.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.divineInkSecondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.divineInkTertiary)
                            .rotationEffect(.degrees(showsHistory ? 0 : -90))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .padding(.top, result == nil ? 8 : 0)

                if showsHistory {
                    // macOS SwiftUI 下 ScrollView 仅设 maxHeight 在自适应窗口里会塌成 0 高度，
                    // 按条数给明确高度，空态与结果态都能稳定展开并滚动。
                    let maxListHeight: CGFloat = result == nil ? 180 : 136
                    let listHeight = min(CGFloat(records.count) * 26 + 8, maxListHeight)
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(records) { record in
                                historyRow(record)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .frame(height: listHeight)
                    .scrollIndicators(.automatic)
                }
            }
        }
    }

    private func historyRow(_ record: DivinationRecord) -> some View {
        let level = journal.result(for: record)?.verdict.level
        let isSelected = result?.createdAt == record.askedAt && result?.question == record.question
        return Button {
            if let restored = journal.result(for: record) {
                question = record.question
                result = restored
                duplicate = nil
                similar = nil
                showsTuan = false
                showsTakashima = false
                interpreter.reset()
                if isAIReady {
                    interpreter.interpret(restored)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(level?.color ?? Theme.divineInkTertiary)
                    .frame(width: 6, height: 6)
                Text(Self.dayText(record.askedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.divineInkTertiary)
                    .monospacedDigit()
                Text(record.question)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Theme.divineInk : Theme.divineInkSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(level?.rawValue ?? "—")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(level?.color ?? Theme.divineInkTertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.divineInset)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private func quotes(_ quotes: [DivinationQuote]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.divineAccent)
                Text("周易原文")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.divineInk)
            }
            ForEach(quotes, id: \.title) { quote in
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.divineInkTertiary)
                    Text(quote.text)
                        .font(.system(size: 13))
                        .foregroundStyle(quote.isPrimary ? Theme.divineInk : Theme.divineInkSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reasons(_ reasons: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.divineInkSecondary)
                Text("断卦依据")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.divineInkSecondary)
            }
            ForEach(reasons, id: \.self) { reason in
                HStack(alignment: .top, spacing: 6) {
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.divineInkTertiary)
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.divineInkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var footer: some View {
        Text("起卦：\(settings.divinationMethod.title)。断语主取《高岛易断》原文，参以《周易》卦爻辞与朱熹《易学启蒙》取辞法。结果供参考，不作决断依据。")
            .font(.system(size: 10))
            .foregroundStyle(Theme.divineInkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
    }

    // MARK: 动作

    private func lineTitles(_ hexagram: Hexagram) -> [String] {
        hexagram.lines.map(\.name)
    }

    /// 清空当前卦象与输入框，回到起卦前界面准备新占一卦。
    private func startNewDivination() {
        castTask?.cancel()
        castTask = nil
        interpreter.reset()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            preparingQuestion = nil
            prepStep = nil
            prepReady = false
            staged = nil
            stagedLines = 0
            rollingIndex = nil
            result = nil
            duplicate = nil
            similar = nil
            showsTuan = false
            showsTakashima = false
            question = ""
        }
        questionFocused = true
    }

    /// 点「解读 / 重新解读」时，如果输入框里改了问题，先用新问题重算高岛切题断语，再交给 AI，避免答旧题。
    private func interpretWithCurrentQuestion(_ current: DivinationResult) {
        NSApp.keyWindow?.makeFirstResponder(nil)
        let live = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty, live != current.question,
           let updated = DivinationEngine.judge(question: live, lines: current.lines, now: current.createdAt) {
            result = updated
            interpreter.interpret(updated)
            return
        }
        interpreter.interpret(current)
    }

    private func cast(force: Bool = false) {
        NSApp.keyWindow?.makeFirstResponder(nil)
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let asked = trimmed.isEmpty ? "此事" : trimmed
        if !force, let existing = journal.record(for: asked) {
            duplicate = existing
            similar = nil
            questionFocused = false
            return
        }
        if !force, let match = journal.similarRecord(for: asked) {
            similar = match
            duplicate = nil
            questionFocused = false
            return
        }
        duplicate = nil
        similar = nil
        showsTuan = false
        showsTakashima = false
        question = asked
        questionFocused = false
        startPreparation(for: asked)
    }

    // MARK: 准备引导 → 正式起卦

    /// 进入起卦前动画引导：依次走过净手澄心 → 专念一事 → 合策默祷，之后等待用户亲手点「我准备好了，开始起卦」。
    private func startPreparation(for asked: String) {
        castTask?.cancel()
        interpreter.reset()
        result = nil
        staged = nil
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            preparingQuestion = asked
            prepStep = 0
            prepReady = false
        }
        castTask = Task { @MainActor in
            // 放慢节奏，让用户真正有时间深呼吸、默念问题与合策默祷（约 10 秒，随时可跳过）
            let durations: [UInt64] = [3_500_000_000, 3_500_000_000, 3_000_000_000]
            for (step, duration) in durations.enumerated() {
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    prepStep = step
                }
                try? await Task.sleep(nanoseconds: duration)
            }
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                prepReady = true
            }
        }
    }

    /// 用户点击「我准备好了，开始起卦」的这一刻，才真正调用系统随机数起卦并开始演爻。
    private func beginActualCast() {
        let asked = preparingQuestion ?? {
            let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "此事" : trimmed
        }()
        castTask?.cancel()
        castTask = nil
        preparingQuestion = nil
        prepStep = nil
        prepReady = false

        let lines = DivinationEngine.cast(method: settings.divinationMethod, seed: nil)
        guard let made = DivinationEngine.judge(question: asked, lines: lines) else { return }
        startCasting(made)
    }

    // MARK: 起卦过程

    /// 卦已经算好了，这里把六爻一爻一爻地演给人看。
    private func startCasting(_ made: DivinationResult) {
        castTask?.cancel()
        interpreter.reset()
        result = nil
        staged = made
        prepStep = nil
        stagedLines = 0
        rollingIndex = nil
        yarrowCounts = []
        coinFaces = [false, false, false]
        coinsSettled = false
        let method = settings.divinationMethod
        castTask = Task { @MainActor in
            for index in 0..<6 {
                if Task.isCancelled { return }
                rollingIndex = index
                if method == .coins {
                    coinsSettled = false
                    for _ in 0..<4 {
                        coinFaces = (0..<3).map { _ in Bool.random() }
                        try? await Task.sleep(nanoseconds: 80_000_000)
                        if Task.isCancelled { return }
                    }
                    coinFaces = Self.faces(for: made.lines[index].value)
                    coinsSettled = true
                    try? await Task.sleep(nanoseconds: 240_000_000)
                } else {
                    yarrowCounts = []
                    for count in DivinationEngine.yarrowCounts(for: made.lines[index].value) {
                        yarrowCounts.append(count)
                        try? await Task.sleep(nanoseconds: 170_000_000)
                        if Task.isCancelled { return }
                    }
                    try? await Task.sleep(nanoseconds: 140_000_000)
                }
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.16)) { stagedLines = index + 1 }
                try? await Task.sleep(nanoseconds: 110_000_000)
            }
            if Task.isCancelled { return }
            finishCasting()
        }
    }

    /// 演完或点「跳过」：落记录、换成完整结果
    private func finishCasting() {
        castTask?.cancel()
        castTask = nil
        guard let made = staged else { return }
        rollingIndex = nil
        prepStep = nil
        stagedLines = 0
        yarrowCounts = []
        journal.add(question: made.question, values: made.lines.map(\.value))
        withAnimation(.easeOut(duration: 0.18)) {
            result = made
            staged = nil
        }
        if AppSettings.shared.llmEnabled && LLMClient.isConfigured {
            interpreter.interpret(made)
        }
    }

    /// 三枚铜钱的正反面：值为 6/7/8/9 时背数为 0/1/2/3
    private static func faces(for value: Int) -> [Bool] {
        let backs = max(0, min(3, value - 6))
        return (0..<3).map { $0 < backs }
    }

    private static func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = Calendar.gregorianMondayFirst.timeZone
        formatter.dateFormat = "M 月 d 日"
        return formatter.string(from: date)
    }
}