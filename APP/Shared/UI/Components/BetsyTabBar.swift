import SwiftUI

// MARK: - Tab definitions
enum BetsyTab: Int, CaseIterable {
    case home    = 0
    case play    = 1
    case league  = 2
    case tickets = 3
    case profile = 4

    func label(lang: AppLang) -> String {
        switch (self, lang) {
        case (.home,    .es): return "INICIO"
        case (.home,    .en): return "HOME"
        case (.play,    .es): return "JUGAR"
        case (.play,    .en): return "PLAY"
        case (.league,  .es): return "LIGA"
        case (.league,  .en): return "LEAGUE"
        case (.tickets, .es): return "APUESTAS"
        case (.tickets, .en): return "BETS"
        case (.profile, .es): return "PERFIL"
        case (.profile, .en): return "PROFILE"
        }
    }

    var icon: String {
        switch self {
        case .home:    return "house.fill"
        case .play:    return "sportscourt.fill"
        case .league:  return "trophy.fill"
        case .tickets: return "ticket.fill"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Reset signal (re-tap on active tab → screen returns to its root)
extension Notification.Name {
    static let betsyTabReset = Notification.Name("betsyTabReset")
    static let betsyOpenArena = Notification.Name("betsyOpenArena")
    static let betsyOpenMatch = Notification.Name("betsyOpenMatch")
    static let betsyDevDayAdvanced = Notification.Name("betsyDevDayAdvanced")
    static let betsyOpenCreateLeague = Notification.Name("betsyOpenCreateLeague")
    static let betsyOpenJoinLeague = Notification.Name("betsyOpenJoinLeague")
    static let betsyAuthChanged = Notification.Name("betsyAuthChanged")
}

// MARK: - Tab bar view
struct BetsyTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @Binding var selected: BetsyTab
    var badges: [BetsyTab: Int] = [:]
    /// Called when the user long-presses any tab (used to open the hidden dev-mode toggle on Profile).
    var onLongPress: ((BetsyTab) -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BetsyTab.allCases, id: \.rawValue) { tab in
                tabItem(tab)
            }
        }
        .frame(height: 82)
        .background(DS.bg1)
        .overlay(Rectangle().fill(DS.line).frame(height: 1), alignment: .top)
    }

    @ViewBuilder
    private func tabItem(_ tab: BetsyTab) -> some View {
        let isActive = selected == tab
        let badgeCount = badges[tab] ?? 0
        Button {
            if selected != tab {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selected = tab
            } else {
                // Re-tap on active tab → reset that tab to its root
                UISelectionFeedbackGenerator().selectionChanged()
                NotificationCenter.default.post(name: .betsyTabReset, object: tab)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? DS.fg : DS.fg3)
                    .overlay(alignment: .topTrailing) {
                        if badgeCount > 0 {
                            Text(badgeCount > 9 ? "9+" : "\(badgeCount)")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(tab == .play ? DS.arena : DS.accent)
                                .foregroundStyle(tab == .play ? .white : DS.accentInk)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(DS.bg1, lineWidth: 2))
                                .offset(x: 10, y: -8)
                                .accessibilityHidden(true)
                        }
                    }
                Text(tab.label(lang: appLang))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(isActive ? DS.fg : DS.fg3)
                Circle()
                    .fill(isActive ? DS.accent : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            tab == .profile
                ? LongPressGesture(minimumDuration: 0.7)
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        onLongPress?(tab)
                    }
                : nil
        )
        .accessibilityLabel(accessibilityLabel(for: tab, badgeCount: badgeCount))
        .accessibilityValue(isActive ? (appLang == .es ? "Seleccionado" : "Selected") : (appLang == .es ? "No seleccionado" : "Not selected"))
        .accessibilityHint(isActive ? (appLang == .es ? "Doble toque para volver al inicio de esta pestaña" : "Double tap to go back to the top of this tab") : (appLang == .es ? "Doble toque para abrir esta pestaña" : "Double tap to open this tab"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.75), value: isActive)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: badgeCount)
    }

    private func accessibilityLabel(for tab: BetsyTab, badgeCount: Int) -> String {
        let name = tab.label(lang: appLang)
        let pending = appLang == .es ? "pendiente" : "pending"
        return badgeCount > 0 ? "\(name), \(badgeCount) \(pending)\(badgeCount == 1 ? "" : "s")" : name
    }
}
