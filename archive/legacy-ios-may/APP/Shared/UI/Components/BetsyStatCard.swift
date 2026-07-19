import SwiftUI

struct BetsyStatCard: View {
    let title: String
    let value: String
    var detail: String? = nil
    var accent: Color = Theme.accent
    var systemImage: String? = nil

    var body: some View {
        BetsyStatBlock(
            title: title,
            value: value,
            detail: detail,
            systemImage: systemImage,
            tone: .dark,
            accent: accent
        )
    }
}
