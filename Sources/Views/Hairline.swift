import SwiftUI

/// 一条极细分割线
struct Hairline: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
            .padding(.horizontal, inset)
    }
}
