import Foundation

/// 五行，用于体用生克判断。
enum Element: String, CaseIterable {
    case metal = "金"
    case wood = "木"
    case water = "水"
    case fire = "火"
    case earth = "土"

    /// 我用什么生它（我生者）。
    private var generates: Element {
        switch self {
        case .metal: return .water
        case .water: return .wood
        case .wood: return .fire
        case .fire: return .earth
        case .earth: return .metal
        }
    }

    /// 我克什么（我克者）。
    private var controls: Element {
        switch self {
        case .metal: return .wood
        case .wood: return .earth
        case .earth: return .water
        case .water: return .fire
        case .fire: return .metal
        }
    }

    /// 从「体」看「用」的关系。
    func relation(towards target: Element) -> Relation {
        if self == target { return .same }
        if generates == target { return .generating }
        if controls == target { return .controlling }
        if target.generates == self { return .generated }
        return .controlled
    }
}

enum Relation {
    /// 体用比和
    case same
    /// 体生用：耗损
    case generating
    /// 体克用：可成但费力
    case controlling
    /// 用生体：得助
    case generated
    /// 用克体：受制
    case controlled

    var text: String {
        switch self {
        case .same: return "体用比和，事在掌握"
        case .generating: return "体生用，出力耗损"
        case .controlling: return "体克用，可为但费力"
        case .generated: return "用生体，外来相助"
        case .controlled: return "用克体，事来相逼"
        }
    }

    /// -1...1，用于合成总判断。
    var score: Double {
        switch self {
        case .same: return 0.5
        case .generating: return -0.5
        case .controlling: return 0.2
        case .generated: return 1
        case .controlled: return -1
        }
    }
}