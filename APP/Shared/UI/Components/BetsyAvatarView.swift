import SwiftUI
import UIKit

struct BetsyAvatarView: View {
    let imageData: Data?
    let name: String
    var size: CGFloat = 40
    var borderColor: Color = Theme.border
    var fillColor: Color = Theme.surfaceAlt
    var textColor: Color = Theme.ink

    private var initials: String {
        let parts = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let value = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return value.isEmpty ? String(name.prefix(1)).uppercased() : value.uppercased()
    }

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    fillColor
                    Text(initials)
                        .font(.system(size: max(size * 0.34, 10), weight: .black))
                        .foregroundStyle(textColor)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(borderColor, lineWidth: 1.5)
        )
    }
}
