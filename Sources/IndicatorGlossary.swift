import Foundation

/// 经济指标小词典：悬停时给出「这是什么」+「对美股的影响」。
/// 文案是通用市场共识，不是投资建议；数据源只给指标名，解释靠这张表。
enum IndicatorGlossary {

    struct Entry: Equatable {
        let title: String
        let meaning: String
        let impact: String
    }

    static func entry(for name: String) -> Entry? {
        let haystack = name.lowercased()
        var best: (keyword: String, entry: Entry)?
        for (keyword, entry) in table where haystack.contains(keyword) {
            if best == nil || keyword.count > best!.keyword.count {
                best = (keyword, entry)
            }
        }
        return best?.entry
    }

    private static let table: [(String, Entry)] = [
        ("core pce", Entry(
            title: "核心 PCE 物价指数",
            meaning: "剔除食品和能源的个人消费支出价格指数，美联储最看重的通胀指标。",
            impact: "高于预期 → 降息预期降温、利率上行，成长股与长久期资产承压；低于预期反之。")),
        ("pce", Entry(
            title: "PCE 物价指数",
            meaning: "个人消费支出价格指数，覆盖面比 CPI 广，权重随消费结构变化。",
            impact: "同上，但核心 PCE 才是联储决策基准，本项影响略小。")),
        ("core cpi", Entry(
            title: "核心 CPI",
            meaning: "剔除食品与能源的消费者物价指数，反映通胀趋势。",
            impact: "高于预期 → 美债收益率上行、压制估值高的科技股；低于预期 → 风险偏好回升。")),
        ("cpi", Entry(
            title: "CPI 消费者物价指数",
            meaning: "居民消费的一篮子商品与服务价格变动，最受关注的通胀数据。",
            impact: "高于预期通常利空美股（加息预期升温），低于预期利多。")),
        ("non-farm payrolls", Entry(
            title: "非农就业人数",
            meaning: "除农业外的就业人数变化，每月第一个周五公布，衡量就业市场强弱。",
            impact: "大幅超预期 → 经济强但降息预期下降，指数震荡偏弱；温和超预期最受股市欢迎。")),
        ("nonfarm payrolls", Entry(
            title: "非农就业人数",
            meaning: "除农业外的就业人数变化，每月第一个周五公布。",
            impact: "过强 → 利率上行压制估值；过弱 → 衰退担忧。温和增长最理想。")),
        ("unemployment rate", Entry(
            title: "失业率",
            meaning: "劳动年龄人口中失业且正在找工作的比例。",
            impact: "失业率抬升 → 降息预期升温，短期利多债券与成长股，但快速上行会引发衰退担忧。")),
        ("average hourly earnings", Entry(
            title: "平均时薪",
            meaning: "私营部门员工平均每小时工资的环比/同比变化，观察工资型通胀。",
            impact: "高于预期 → 工资通胀压力，利空美股；是「工资—物价螺旋」的关键观察点。")),
        ("adp", Entry(
            title: "ADP 就业人数",
            meaning: "自动数据处理公司的私营部门就业估算，被视为非农的先行指标。",
            impact: "方向常与非农一致，但偏差较大，通常只引起盘中短暂波动。")),
        ("gdp price index", Entry(
            title: "GDP 价格指数",
            meaning: "GDP 平减指数，衡量整体物价水平变化。",
            impact: "高于预期提示通胀黏性，对美股偏空。")),
        ("prelim gdp", Entry(
            title: "GDP 初值（季调环比折年）",
            meaning: "国内生产总值第一次估算，反映经济增速。",
            impact: "太强 → 降息预期下降；太弱 → 衰退担忧。温和增长对美股最友好。")),
        ("final gdp", Entry(
            title: "GDP 终值",
            meaning: "GDP 的最终修订值，通常已提前被市场消化。",
            impact: "影响一般较小，除非大幅修正。")),
        ("gdp", Entry(
            title: "GDP 国内生产总值",
            meaning: "一国经济产出的总规模，衡量增长动能。",
            impact: "适度增长利多盈利预期，过热则引发紧缩担忧。")),
        ("core retail sales", Entry(
            title: "核心零售销售",
            meaning: "剔除汽车、汽油等波动项的零售销售，反映消费韧性。",
            impact: "超预期 → 消费强、经济软着陆预期升温，利多消费与周期股。")),
        ("retail sales", Entry(
            title: "零售销售",
            meaning: "零售端销售额变化，消费占美国经济约七成，是需求端核心指标。",
            impact: "超预期利多消费股；但若同时推升通胀预期，利率敏感板块会承压。")),
        ("ism manufacturing", Entry(
            title: "ISM 制造业 PMI",
            meaning: "采购经理人指数，50 为荣枯线，衡量制造业扩张或收缩。",
            impact: "高于 50 且超预期 → 周期股受益；跌破 50 会引发增长担忧。")),
        ("ism services", Entry(
            title: "ISM 服务业 PMI",
            meaning: "服务业采购经理人指数，美国经济以服务业为主，权重更高。",
            impact: "超预期利多美股（经济有韧性），但过热会推升利率。")),
        ("s&p global", Entry(
            title: "S&P Global PMI",
            meaning: "标普全球编制的综合/制造业/服务业 PMI 初值。",
            impact: "对美股影响中等，主要看是否跌破 50 荣枯线。")),
        ("ism", Entry(
            title: "ISM PMI",
            meaning: "供应管理协会采购经理人指数，50 为荣枯线。",
            impact: "超预期利多周期股，跌破 50 引发增长担忧。")),
        ("jobless claims", Entry(
            title: "初请失业金人数",
            meaning: "每周首次申请失业救济人数，频率最高、反映就业市场边际变化。",
            impact: "低于预期 → 就业稳健、利率上行；持续抬升则被视为经济走弱的早期信号。")),
        ("ppi", Entry(
            title: "PPI 生产者物价指数",
            meaning: "生产端出厂价格变化，通常领先 CPI。",
            impact: "高于预期 → 通胀传导担忧，利空美股。")),
        ("consumer confidence", Entry(
            title: "消费者信心指数",
            meaning: "调查消费者对当前经济与未来预期的乐观程度。",
            impact: "超预期利多消费股；明显走弱会引发消费降温担忧。")),
        ("consumer sentiment", Entry(
            title: "密歇根消费者信心",
            meaning: "密歇根大学的消费者调查，含通胀预期分项。",
            impact: "通胀预期分项上行常引发利率上行、压制美股。")),
        ("existing home sales", Entry(
            title: "成屋销售",
            meaning: "二手住宅成交年化户数，对利率高度敏感。",
            impact: "影响偏局部，主要看房贷利率与地产链个股。")),
        ("new home sales", Entry(
            title: "新屋销售",
            meaning: "新建住宅成交年化户数。",
            impact: "影响偏局部，地产与家居零售股关注度高。")),
        ("building permits", Entry(
            title: "营建许可",
            meaning: "获批的新建住房许可数量，领先于实际开工。",
            impact: "影响偏局部，反映地产投资前景。")),
        ("housing starts", Entry(
            title: "新屋开工",
            meaning: "新建住宅开工户数。",
            impact: "影响偏局部，地产链与建材股关注。")),
        ("durable goods", Entry(
            title: "耐用品订单",
            meaning: "使用寿命三年以上的商品订单，反映企业投资意愿。",
            impact: "超预期利多工业与资本品板块。")),
        ("factory orders", Entry(
            title: "工厂订单",
            meaning: "制造业新订单总额。",
            impact: "影响中等，反映制造业需求。")),
        ("industrial production", Entry(
            title: "工业产出",
            meaning: "工业部门实际产出变化。",
            impact: "超预期利多工业股。")),
        ("trade balance", Entry(
            title: "贸易帐",
            meaning: "商品与服务进出口差额。",
            impact: "对美股整体影响小，主要影响美元与跨国企业盈利预期。")),
        ("fomc", Entry(
            title: "FOMC 议息会议",
            meaning: "美联储联邦公开市场委员会，决定联邦基金利率区间。",
            impact: "美股波动最大的事件：点阵图与措辞比决议本身更重要，鹰派→杀估值，鸽派→普涨。")),
        ("federal funds rate", Entry(
            title: "联邦基金利率决议",
            meaning: "美联储公布的目标利率区间。",
            impact: "降息利多成长股与长久期资产，加息或延后降息则相反。")),
        ("crude oil inventories", Entry(
            title: "EIA 原油库存",
            meaning: "美国商业原油库存周度变化。",
            impact: "影响能源板块；库存大降推高油价，利多能源股、利空航空与运输。")),
        ("natural gas storage", Entry(
            title: "天然气库存",
            meaning: "美国天然气库存周度变化。",
            impact: "影响能源股与公用事业成本。")),
        ("jolts", Entry(
            title: "JOLTS 职位空缺",
            meaning: "调查企业未填补岗位数，衡量劳动力需求松紧。",
            impact: "空缺下降 → 就业降温、降息预期升温，短期利多美股。")),
        ("challenger", Entry(
            title: "挑战者裁员人数",
            meaning: "企业公布的计划裁员数。",
            impact: "裁员激增 → 经济走弱信号，但也会强化降息预期，反应常双向。")),
        ("employment cost index", Entry(
            title: "就业成本指数",
            meaning: "包含工资与福利的劳动力成本变化，美联储关注的工资通胀指标。",
            impact: "高于预期 → 通胀黏性，利空美股。")),
        ("treasury budget", Entry(
            title: "联邦财政预算",
            meaning: "月度财政收支差额。",
            impact: "对美股影响小，主要影响美债供给预期。")),
        ("nahb", Entry(
            title: "NAHB 房产市场指数",
            meaning: "全美住宅建筑商协会信心指数。",
            impact: "影响偏局部，地产链关注。")),
        ("empire state", Entry(
            title: "纽约联储制造业指数",
            meaning: "纽约州制造业景气调查。",
            impact: "影响中等，是制造业景气的早期信号。")),
        ("philly fed", Entry(
            title: "费城联储制造业指数",
            meaning: "宾州地区制造业景气调查。",
            impact: "影响中等，与 ISM 制造业方向常一致。")),
        ("chicago pmi", Entry(
            title: "芝加哥 PMI",
            meaning: "芝加哥地区采购经理人指数。",
            impact: "影响中等，常被用来预判全国 ISM。")),
        ("leading index", Entry(
            title: "领先指标指数",
            meaning: "综合多项先行数据的景气指数。",
            impact: "影响较小，用于判断周期方向。")),
        ("wholesale inventories", Entry(
            title: "批发库存",
            meaning: "批发环节库存变化。",
            impact: "影响小，用于修正 GDP 库存分项。")),
        ("business inventories", Entry(
            title: "商业库存",
            meaning: "企业库存水平变化。",
            impact: "影响小。")),
        ("current account", Entry(
            title: "经常帐",
            meaning: "贸易、投资收益与转移支付的综合收支。",
            impact: "影响小，主要影响美元。")),
        ("fed chair", Entry(
            title: "美联储主席讲话",
            meaning: "主席公开发言，常透露政策倾向。",
            impact: "措辞偏鹰 → 利率上行、美股承压；偏鸽 → 风险偏好回升。")),
        ("fed member", Entry(
            title: "美联储官员讲话",
            meaning: "地区联储主席或理事的公开发言。",
            impact: "影响通常小于主席发言，但密集鹰派表态会累积压制估值。")),
        ("fed speak", Entry(
            title: "美联储官员讲话",
            meaning: "联储官员公开表态。",
            impact: "偏鹰利空、偏鸽利多，视市场当前预期而定。")),
        ("michigan", Entry(
            title: "密歇根大学消费者调查",
            meaning: "含现状指数、预期指数与通胀预期。",
            impact: "通胀预期分项抬升会推高利率、压制美股。"))
    ]
}