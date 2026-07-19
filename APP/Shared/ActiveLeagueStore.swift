import Foundation

enum ActiveLeagueStore {
    static let storageKey = "selectedLeagueId"

    static func resolve(from leagues: [FriendLeague], selectedId: String) -> FriendLeague? {
        if let selected = leagues.first(where: { $0.id == selectedId }) {
            return selected
        }
        return leagues.first
    }
}
