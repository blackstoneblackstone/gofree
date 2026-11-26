<div align="center">

<img src="design/icon-1024.png" width="88" height="88" alt="gofree icon" />

# gofree

**极简原生的 macOS 菜单栏万年历、美股财经日历、《高岛易断》占卦与 3D 定时休息提醒工具**

[![macOS](https://img.shields.io/badge/macOS-15.0%2B-000000?logo=apple&logoColor=white)](https://github.com/blackstoneblackstone/gofree/releases/latest)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-3B6CF5?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Release](https://img.shields.io/github/v/release/blackstoneblackstone/gofree?color=22C55E&label=Release)](https://github.com/blackstoneblackstone/gofree/releases/latest)
[![Build](https://img.shields.io/github/actions/workflow/status/blackstoneblackstone/gofree/release.yml?branch=main&label=DMG%20Build)](https://github.com/blackstoneblackstone/gofree/actions)

[下载最新 DMG](https://github.com/blackstoneblackstone/gofree/releases/latest) · [功能亮点](#功能亮点) · [安装说明](#安装与使用) · [本地构建](#本地构建与开发)

</div>

---

`gofree` 是一款纯原生 SwiftUI 打造的 macOS 菜单栏应用（无 Electron，支持浅色 / 深色模式自适应）。点开菜单栏即可一屏看完 **农历黄历、法定休班、实时天气、美股财报与宏观数据**，并内置以 **《高岛易断》** 为核心的「占一事」易占与 AI 解卦功能，以及带 **Blender 3D 动作演示与分步倒计时** 的「定时休息提醒」。

<p align="center">
  <img src="design/preview.png" width="320" alt="菜单栏日历预览" />
  &nbsp;&nbsp;&nbsp;
  <img src="design/preview-divine.png" width="560" alt="高岛易断占一事预览" />
</p>

## 功能亮点

### 1. 离线万年历与传统黄历

<p align="center">
  <img src="design/feature-calendar-16x9.png" width="840" alt="离线万年历与传统黄历功能介绍" />
</p>

- **菜单栏常驻**：顶部显示今日日期与星期（如 `11/26 周四`），每分钟自动刷新。
- **7×6 月历与两月放大视图**：公历、农历、24 节气、传统与公历节日一目了然，翻月纯本地计算、零延迟。
- **法定休 / 班角标**：内置国务院办公厅放假调休安排，并按需联网拉取后续年份数据。
- **17 项黄历详情**：生肖、星座、干支（立春换年）、星宿、五行、冲煞、彭祖百忌、胎神占方、六曜、十二神等。
- **天气与系统日程**：内置 Open-Meteo 天气（支持自定义城市、实况/预报/历史缓存），可选接入 macOS EventKit 系统日程。

### 2. 美股财经日历（S&P 500 过滤）

<p align="center">
  <img src="design/feature-market-16x9.png" width="840" alt="美股财经日历功能介绍" />
</p>

- **大公司财报**：自动过滤标普 500 成分股，展示盘前/盘后与 EPS 预期。
- **重要宏观经济数据**：覆盖 CPI、PCE、非农、FOMC 议息决议等关键事件（北京时间 + 五星级重要度），**悬停任意指标可查看含义与对美股的影响**。
- **休市、提前收盘与期权到期**：内置纽交所官方休市、提前收盘（13:00 ET 换算北京时间）与月度/四巫日期权到期标记。

### 3. 「占一事」·《高岛易断》与 AI 解卦

<p align="center">
  <img src="design/feature-divine-16x9.png" width="840" alt="高岛易断与 AI 解卦功能介绍" />
</p>

- **三种古法起卦**：
  - **高岛略筮（默认）**：《高岛易断》所用三变筮法（四十九策分二挂一，定下卦、上卦与唯一动爻），直对高岛六爻断语。
  - **三枚铜钱** & **大衍之数（十八变）**：完整模拟古法概率分布，全程调用系统真随机数 `SystemRandomNumberGenerator`。
- **Blender 3D 仪轨动效**：起卦准备、静心默念与动态起卦阶段分别展示 **现代八卦浑天仪**、**四十九策聚光仪** 与 **三枚外圆内方古铜钱** 真 3D 模型（`.usdz`），支持鼠标拖拽 360° 旋转，浅色 / 深色双主题自适应。
- **《高岛易断》切题取断**：自动解析 64 卦卦断与 384 爻断，按所问事项精准匹配「问营商 / 商业 / 功名 / 家宅 / 婚姻 / 疾病 / 讼事 / 出行 / 时运」等门类，并可一键展开完整断例与《周易》卦爻辞、《彖传》。
- **AI 结合原问题解卦**：支持配置任意 OpenAI 兼容接口（Base URL / 模型名 / API Key 仅存本机），紧扣你问的具体问题与《高岛易断》原典给出平实直白的判断，且左栏结论印鉴与 AI 研判自动同步。
- **一事不二占 & 往占记录**：重复或相近问法自动提醒，所有往占自动落盘本机，随时点击回看。

### 4. 定时休息提醒（Blender 3D 动作演示 + 分步引导）

<p align="center">
  <img src="design/feature-rest-reminder-16x9.png" width="840" alt="定时休息提醒功能介绍" />
</p>

- **两类共 7+1 套职场友好休息方式**：
  - **一、留在工位：0 破绽的「隐形休息」**：「托腮/扶额」伪装深思、桌子底下的肌肉松绑（勾脚尖/绷脚背）、戴降噪耳机只听环境音、切去低耗能伪装任务。
  - **二、离开工位：用「合理借口」彻底断电 3 分钟**：不带手机去洗手间（最管用）、刻意把接水拉长到 3 分钟、借拿快递/接电话去楼梯间伸懒腰或下楼晒太阳。
  - **下午犯困急救组合**：「不带手机去洗手间闭眼 2 分钟 + 冷水冲手腕」，下午时段（13:00–18:00）自动高亮提示。
- **8 套 Blender 3D 动作演示（`.usdz`）**：使用 Blender 建模并导出带 120 帧循环关键帧动画的 `.usdz` 微缩 3D 场景，支持鼠标拖拽 360° 旋转查看，浅色 / 深色双主题自适应。
- **分步倒计时引导**：每项休息拆分为 3 个可执行步骤；点击「开始休息」后，右上角非抢焦点浮窗自动随倒计时推进第 1 → 2 → 3 步，高亮当前步骤进度条与剩余秒数。
- **智能交替策略与贴心控制**：默认每 45 分钟提醒一次，工位隐形休息与离座断电交替触发（每隔 1–1.5 小时离座断电一次），也可切换仅留在工位 / 仅离开工位；支持电脑休眠唤醒后自动重置计时、仅工作时段（9:00–19:00）、轻柔提示音与 10 分钟稍后提醒。
- **投屏 / 共享屏幕时不自动弹出**：无需录屏权限即可检测屏幕镜像、AirPlay 投屏、会议软件共享屏幕（飞书 / 腾讯会议 / Zoom / 钉钉 / Teams / 微信）及 Keynote / PowerPoint 全屏演示；投屏期间定时到点自动顺延 5 分钟不弹出，主动打开时仍正常展示。

## 安装与使用

> 系统要求：**macOS 15.0（Sequoia）及以上**（Apple Silicon）

1. 前往 [Releases 页面](https://github.com/blackstoneblackstone/gofree/releases/latest) 下载最新的 `gofree-v*-arm64.dmg`。
2. 双击打开 DMG，将 `gofree.app` 拖入 `Applications` 文件夹。
3. **首次打开说明**：本项目采用 ad-hoc 签名（未经过付费 Apple 开发者账号公证），首次启动如遇系统 Gatekeeper 拦截，任选以下一种方式放行即可：
   - 打开「系统设置 → 隐私与安全性」，在底部找到 `gofree`，点击「仍要打开」；
   - 或在终端执行：
     ```bash
     xattr -dr com.apple.quarantine "/Applications/gofree.app"
     ```

## 本地构建与开发

```bash
# 1. 克隆仓库
git clone https://github.com/blackstoneblackstone/gofree.git
cd gofree

# 2. 生成 Xcode 工程并编译 Release 版（需 Xcode 16+，可选 brew install xcodegen）
./tools/build.sh

# 3. 打包成 DMG（输出到 dist/gofree.dmg）
./tools/package_dmg.sh

# 4. 运行 170+ 项内置自检
./build/Build/Products/Release/gofree.app/Contents/MacOS/gofree --selftest
```

### 常用命令行调试入口

```bash
# 命令行起一卦（支持 takashima / coins / yarrow）
gofree --divine "这周要不要加仓" --method takashima

# 用已配置的大模型测试解卦
gofree --llm "年底前跳槽机会怎么样" --seed 12

# 查询某日美股事件或天气
gofree --market 2026-11-26
gofree --weather 杭州 2026-11-26

# 截取定时休息浮窗 / 指南窗口预览图（TC_PREVIEW_DARK=1 切深色模式）
TC_PREVIEW_REST_POPUP=1 TC_PREVIEW_DARK=0 gofree --preview /tmp/rest-light.png 2026-11 26
TC_PREVIEW_REST_POPUP=1 TC_PREVIEW_REST_ACTIVE=1 TC_PREVIEW_DARK=1 gofree --preview /tmp/rest-dark.png 2026-11 26

# 使用本机 Blender 重新生成全部 3D 模型（定时休息 8 套 + 占一事 3 套）
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/generate_rest_3d.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/generate_divine_3d.py
```

## 项目结构

```text
Sources/
├── App.swift                  # 菜单栏入口与窗口调度
├── AlmanacEngine.swift        # 农历、节气、黄历本地计算
├── MarketCalendar.swift       # 美股财报、宏观事件、休市与期权到期
├── WeatherService.swift       # Open-Meteo 天气与本地缓存
├── LLMClient.swift            # OpenAI 兼容模型客户端
├── RestReminder.swift         # 定时休息调度、分步引导与 7+1 套休息方案
├── ScreenSharingDetector.swift # 投屏 / 镜像 / 共享屏幕 / 全屏演示检测
├── IChing/                    # 起卦引擎、高岛易断解析与切题匹配、AI 提示词
└── Views/                     # SwiftUI 界面、SceneKit USDZ 3D 舞台与动效
Resources/
├── iching.json                # 六十四卦《周易》原文与《高岛易断》全本
├── Holidays.json              # 中国法定节假日与调休数据
├── sp500.txt                  # 标普 500 成分股过滤列表
├── DivineModels/              # 3 套 Blender 导出的占卦 3D 模型（.usdz）
└── RestModels/                # 8 套 Blender 导出的休息 3D 动画模型（.usdz）
Vendor/LunarSwift/             # 内置 MIT 农历算法库
tools/                         # 构建、调试、DMG 打包与 Blender 3D 生成脚本
.github/workflows/release.yml  # 合并 main 自动编译自检并发布 DMG
```

## 数据来源与致谢

- **农历与黄历算法**：[6tail/lunar-swift](https://github.com/6tail/lunar-swift)（MIT License）
- **法定节假日**：国务院办公厅放假通知 / [NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn)
- **天气数据**：[Open-Meteo](https://open-meteo.com/)（免 Key）
- **《周易》与《高岛易断》**：[中文维基文库《周易》](https://zh.wikisource.org/wiki/周易) 与高岛嘉右卫门《高岛易断》（公有领域古籍）

## 开源协议

本项目基于 **MIT License** 开源，欢迎提 Issue 与 PR。

> 免责声明：占卦与财经事件数据仅供日常参考与学习研究，不构成任何投资、医疗或法律建议。
