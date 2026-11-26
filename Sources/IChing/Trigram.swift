import Foundation

/// 八卦。爻画自下而上，`bits` 第一个元素是最下一爻，true 为阳。
enum Trigram: String, CaseIterable, Identifiable {
    case qian = "乾"
    case dui = "兑"
    case li = "离"
    case zhen = "震"
    case xun = "巽"
    case kan = "坎"
    case gen = "艮"
    case kun = "坤"

    var id: String { rawValue }

    /// 卦名在部分古籍里写作「干」，统一归到「乾」。
    init?(name: String) {
        switch name {
        case "乾", "干": self = .qian
        default:
            guard let value = Trigram(rawValue: name) else { return nil }
            self = value
        }
    }

    var symbol: String {
        switch self {
        case .qian: return "☰"
        case .dui: return "☱"
        case .li: return "☲"
        case .zhen: return "☳"
        case .xun: return "☴"
        case .kan: return "☵"
        case .gen: return "☶"
        case .kun: return "☷"
        }
    }

    var nature: String {
        switch self {
        case .qian: return "天"
        case .dui: return "泽"
        case .li: return "火"
        case .zhen: return "雷"
        case .xun: return "风"
        case .kan: return "水"
        case .gen: return "山"
        case .kun: return "地"
        }
    }

    var element: Element {
        switch self {
        case .qian, .dui: return .metal
        case .li: return .fire
        case .zhen, .xun: return .wood
        case .kan: return .water
        case .gen, .kun: return .earth
        }
    }

    var bits: [Bool] {
        switch self {
        case .qian: return [true, true, true]
        case .dui: return [true, true, false]
        case .li: return [true, false, true]
        case .zhen: return [true, false, false]
        case .xun: return [false, true, true]
        case .kan: return [false, true, false]
        case .gen: return [false, false, true]
        case .kun: return [false, false, false]
        }
    }
}