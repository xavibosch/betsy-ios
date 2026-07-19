import SwiftUI

struct BetsySegmentedControl<Option: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let options: [Option]
    @Binding var selection: Option
    var title: (Option) -> String

    init(
        options: [Option],
        selection: Binding<Option>,
        title: @escaping (Option) -> String
    ) {
        self.options = options
        self._selection = selection
        self.title = title
    }

    var body: some View {
        BetsyCard(
            tone: .light,
            padding: Theme.Spacing.xxs,
            radius: 0,
            borderColor: Theme.paperLine
        ) {
            HStack(spacing: Theme.Spacing.xxs) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selection

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.78)) {
                            selection = option
                        }
                    } label: {
                        Text(title(option))
                            .font(Theme.Typography.sectionTitle)
                            .foregroundStyle(isSelected ? Theme.paper : Theme.bg.opacity(0.58))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isSelected ? Theme.bg : Theme.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0, style: .continuous)
                                    .stroke(isSelected ? Theme.bg : Theme.paperLine, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.78), value: isSelected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title(option))
                    .accessibilityValue(isSelected ? "Seleccionado" : "No seleccionado")
                    .accessibilityHint("Doble toque para cambiar de sección")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selector de sección")
    }
}
