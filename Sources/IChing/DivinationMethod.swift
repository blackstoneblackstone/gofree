import Foundation

/// 起卦方式：
/// - 高岛略筮（三变筮法）：《高岛易断》所用古法，五十策用四十九，三变定下卦、上卦与一动爻，必出一动爻，直对高岛爻断。
/// - 三枚铜钱：六次成卦，爻值 6/7/8/9。
/// - 大衍之数：十八变成卦，老阳 3/16、少阴 7/16、少阳 5/16、老阴 1/16。
enum DivinationMethod: String, CaseIterable, Identifiable, Codable {
    case takashima
    case coins
    case yarrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .takashima: return "高岛略筮"
        case .coins: return "三枚铜钱"
        case .yarrow: return "大衍之数"
        }
    }

    var caption: String {
        switch self {
        case .takashima: return "四十九策，三变定卦与一动爻"
        case .coins: return "三枚铜钱，六次成卦"
        case .yarrow: return "四十九策，十八变成卦"
        }
    }
}