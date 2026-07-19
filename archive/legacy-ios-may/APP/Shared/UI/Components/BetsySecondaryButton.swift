import SwiftUI

struct BetsySecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        BetsyButton(
            title: title,
            systemImage: systemImage,
            style: .secondary,
            isDisabled: isDisabled,
            action: action
        )
    }
}
