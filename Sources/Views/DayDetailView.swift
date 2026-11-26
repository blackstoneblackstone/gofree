import SwiftUI

struct DayDetailView: View {
    let detail: DayDetailModel
    @Binding var showsMore: Bool
    var market = MarketDay()
    var marketLoading = false
    var showsAlmanac = true

    @State private var hoveredRow: MarketRow?
    /// 每行在详情卡坐标系里的位置，用来把解释卡贴到悬停行旁边
    @State private var rowFrames: [String: CGRect] = [:]
    /// 解释卡自身高度与美股区块高度，用来判断朝上还是朝下放
    @State private var helpCardHeight: CGFloat = 0
    @State private var marketSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !detail.festivals.isEmpty {
                FlowLayout(spacing: 5, lineSpacing: 5) {
                    ForEach(detail.festivals, id: \.self) { name in
                        Chip(text: name, color: Theme.festival)
                    }
                }
            }

            if showsMarket {
                marketSection(leadingDivider: !detail.festivals.isEmpty)
            }

            if showsAlmanac, !detail.info.isEmpty {
                moreSection(divider: !detail.festivals.isEmpty || showsMarket)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.cardStroke, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 3)
        )
    }

    // MARK: - 美股

    /// 只在确实有事件（或正在取）时出现，避免每天多出一块空白
    private var showsMarket: Bool {
        !market.isEmpty || marketLoading
    }

    private func marketSection(leadingDivider: Bool) -> some View {
        marketContent(leadingDivider: leadingDivider)
            .coordinateSpace(name: Self.marketSpace)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { marketSize = $0 }
            .overlay(alignment: .topLeading) {
                if let (help, rect) = helpTarget(in: rowFrames) {
                    helpCard(help)
                        .frame(width: Self.helpCardWidth, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { helpCardHeight = $0 }
                        .offset(y: cardOffset(for: rect))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.1), value: hoveredRow?.id)
    }

    private static let helpCardWidth: CGFloat = 320
    private static let cardGap: CGFloat = 6

    /// 解释卡放哪一側：区块内上方放得下就朝上；放不下但下方放得下就朝下（只压住「更多信息」那一带）；
    /// 两边都放不下时仍然朝上，宁可溢出到日历区域，也不遮住下面几行要对比的数据。
    private func cardOffset(for rect: CGRect) -> CGFloat {
        let gap = Self.cardGap
        // 首次渲染还没量到高度时，按一行高的估计值先算，量完会立刻校正
        let height = helpCardHeight > 0 ? helpCardHeight : 92
        let above = rect.minY - gap - height
        if above >= 0 { return above }
        let below = rect.maxY + gap
        if below + height <= marketSize.height { return below }
        return above
    }

    /// 悬停行；TC_PREVIEW_HOVER=1 时固定取第一条有词条的行（截图核对用）
    private func helpTarget(in frames: [String: CGRect])
        -> (IndicatorGlossary.Entry, CGRect)? {
        if let row = hoveredRow, let help = row.help, let rect = frames[row.id] {
            return (help, rect)
        }
        // 截图核对：TC_PREVIEW_HOVER=1 用第一条有词条的行，也可以传关键字指定词条
        guard let value = ProcessInfo.processInfo.environment["TC_PREVIEW_HOVER"],
              let first = allRows.first(where: { $0.help != nil }),
              let rect = frames[first.id] else { return nil }
        if value == "1", let help = first.help { return (help, rect) }
        if let entry = IndicatorGlossary.entry(for: value.lowercased()) { return (entry, rect) }
        return nil
    }

    /// 悬停解释卡：贴在悬停行上方（可以向上溢出卡片边界，不会被裁掉）
    private func helpCard(_ help: IndicatorGlossary.Entry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(help.title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            Text(help.meaning)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 4) {
                Text("对美股")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(help.impact)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: Self.helpCardWidth, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.cardSolid)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.cardSolidStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 16, x: 0, y: 6)
        )
    }

    private func marketContent(leadingDivider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if leadingDivider {
                Hairline().padding(.horizontal, -14)
            }

            HStack(spacing: 5) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .accessibilityHidden(true)
                    .font(.system(size: 11, weight: .semibold))
                Text("今日事件")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                if market.isMarketClosed {
                    Chip(text: "休市", color: Theme.festival)
                } else if market.earlyCloseReason != nil {
                    Chip(text: "提前收盘", color: Theme.textSecondary)
                }
                if market.isFOMC {
                    Chip(text: "FOMC 决议", color: Theme.festival)
                }
                if market.isQuadWitching {
                    Chip(text: "四巫日", color: Theme.textSecondary)
                } else if market.isOptionExpiry {
                    Chip(text: "期权到期", color: Theme.textSecondary)
                }
                Spacer(minLength: 0)
                if marketLoading {
                    ProgressView().controlSize(.mini)
                }
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 8)

            if let reason = market.closedReason {
                Text("\(reason) · 全天休市")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            } else if let reason = market.earlyCloseReason {
                Text("\(reason) · 13:00 ET 收盘（北京\(market.earlyCloseBeijingTime ?? "")）")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(visibleRows) { row in
                marketRow(row)
            }

            if let footer = marketFooter {
                Text(footer)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.leading, Self.textIndent)
            }

            if marketLoading && visibleRows.isEmpty && !market.isFOMC && market.earlyCloseReason == nil
                && !market.isMarketClosed {
                Text("正在获取财报与经济数据…")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // 统一成一张四列表格：时间/代码 | 星级 | 名称 | 数值，两组数据共用列宽才不会错位
    private static let leftColumn: CGFloat = 38
    private static let midColumn: CGFloat = 40
    private static let valueColumn: CGFloat = 68
    private static let columnGap: CGFloat = 8
    private static let maxRows = 6
    private static let marketSpace = "marketSection"
    /// 名称列起点：左列 + 星级列 + 两个列间距
    private static var textIndent: CGFloat { leftColumn + midColumn + columnGap * 2 }

    private struct MarketRow: Identifiable {
        let id: String
        let left: String
        let stars: Int
        let symbol: String?
        let title: String
        let value: String
        /// 悬停提示：指标解释 + 对美股的影响
        let help: IndicatorGlossary.Entry?
    }

    private var allRows: [MarketRow] {
        var rows: [MarketRow] = []
        for event in market.economy {
            rows.append(MarketRow(id: "e-\(event.id)", left: event.time, stars: event.stars,
                                  symbol: nil, title: event.name,
                                  value: event.consensus.isEmpty ? "" : "预期 \(event.consensus)",
                                  help: IndicatorGlossary.entry(for: event.name)))
        }
        if !market.isMarketClosed {
            for event in market.earnings where event.isMajor {
                rows.append(MarketRow(id: "r-\(event.symbol)", left: event.session, stars: 0,
                                      symbol: event.symbol, title: event.name,
                                      value: event.eps.isEmpty ? "" : "EPS \(event.eps)",
                                      help: nil))
            }
        }
        return rows
    }


    private var marketFooter: String? {
        var parts: [String] = []
        if hiddenRowCount > 0 { parts.append("还有 \(hiddenRowCount) 条") }
        if smallEarningsCount > 0 { parts.append("另有 \(smallEarningsCount) 家小公司财报") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var visibleRows: [MarketRow] { Array(allRows.prefix(Self.maxRows)) }
    private var hiddenRowCount: Int { max(0, allRows.count - Self.maxRows) }
    private var smallEarningsCount: Int {
        market.isMarketClosed ? 0 : max(0, market.earnings.count - market.majorEarningsCount)
    }

    private func marketRow(_ row: MarketRow) -> some View {
        HStack(spacing: Self.columnGap) {
            Text(row.left.isEmpty ? "—" : row.left)
                .font(.system(size: 10, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
                .frame(width: Self.leftColumn, alignment: .leading)

            if let symbol = row.symbol {
                Text(symbol)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .frame(width: Self.midColumn, alignment: .leading)
            } else {
                StarRating(level: row.stars)
                    .frame(width: Self.midColumn, alignment: .leading)
            }

            HStack(spacing: 3) {
                Text(row.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                if row.help != nil {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary.opacity(0.75))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.value)
                .font(.system(size: 10, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .frame(width: Self.valueColumn, alignment: .trailing)
        }
        .frame(height: 19)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.marketSpace))
        } action: { frame in
            rowFrames[row.id] = frame
        }
        .onHover { inside in
            if inside {
                hoveredRow = row
            } else if hoveredRow?.id == row.id {
                hoveredRow = nil
            }
        }
        // 点一下也能锁定解释卡（万一悬停不灵），再点收起
        .onTapGesture {
            hoveredRow = hoveredRow?.id == row.id ? nil : row
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText(for: row)))
        .accessibilityAddTraits(row.help == nil ? [] : .isButton)
    }

    /// 把「时间 名称 星级/代码 数值」拼成一句给 VoiceOver
    private func accessibilityText(for row: MarketRow) -> String {
        var parts: [String] = []
        if !row.left.isEmpty { parts.append(row.left) }
        if let symbol = row.symbol {
            parts.append(symbol)
        } else if row.stars > 0 {
            parts.append("重要级别 \(row.stars) 星，共 5 星")
        }
        parts.append(row.title)
        if !row.value.isEmpty { parts.append(row.value) }
        return parts.joined(separator: "，")
    }


    // MARK: - 更多信息

    private func moreSection(divider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if divider {
                Hairline().padding(.horizontal, -14)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showsMore.toggle() }
            } label: {
                HStack(spacing: 3) {
                    Text(showsMore ? "收起" : "更多信息")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(showsMore ? 180 : 0))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .padding(.top, divider ? 5 : 0)

            if showsMore {
                infoGrid.padding(.top, 2)
            }
        }
    }

    private var infoGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12, alignment: .top),
                       GridItem(.flexible(), spacing: 12, alignment: .top)]
        return ScrollView(.vertical) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(detail.info) { row in
                    HStack(alignment: .top, spacing: 5) {
                        Text(row.title)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 44, alignment: .leading)
                        Text(row.value)
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(10)
        }
        .scrollIndicators(.hidden)
        .frame(height: 190)
        // 内容底部渐隐，提示还能往下滚；面板本身不受影响
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.97),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.innerFill)
        )
    }
}