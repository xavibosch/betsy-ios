import SwiftUI

struct BetsyPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        BetsyButton(
            title: title,
            systemImage: systemImage,
            style: .primary,
            isDisabled: isDisabled,
            action: action
        )
    }
}
