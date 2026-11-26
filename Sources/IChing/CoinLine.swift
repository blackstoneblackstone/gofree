import Foundation

/// 一爻的起卦结果。三枚铜钱，字为阴、背为阳：
/// 三字为老阴（6，变阳）、一背为少阳（7）、二背为少阴（8）、三背为老阳（9，变阴）。
struct CoinLine: Hashable {
    let value: Int

    var isYang: Bool { value == 7 || value == 9 }

    var isChanging: Bool { value == 6 || value == 9 }

    var label: String {
        switch value {
        case 6: return "老阴"
        case 7: return "少阳"
        case 8: return "少阴"
        default: return "老阳"
        }
    }

    /// 变爻在图上加的记号：老阳记 ○，老阴记 ×。
    var mark: String? {
        switch value {
        case 9: return "○"
        case 6: return "×"
        default: return nil
        }
    }
}