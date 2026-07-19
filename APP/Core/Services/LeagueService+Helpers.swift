import FirebaseFirestore

// MARK: - Firestore encode/decode helpers & code generator

extension LeagueService {

    // MARK: Code generator

    func generateCode(length: Int) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    // MARK: Settings normalisation

    func normalizedSettings(_ settings: LeagueSettings) -> LeagueSettings {
        var s = settings
        s.allowedCompetitions = settings.allowedCompetitions.isEmpty
            ? LeagueCompetition.allCases
            : settings.allowedCompetitions
        s.initialBalance   = max(settings.initialBalance,   1)
        s.betsPerActiveDay = max(settings.betsPerActiveDay, 1)
        if s.betWindowPreset != .custom {
            s.activeWeekdays = []
        } else if s.activeWeekdays.isEmpty {
            s.activeWeekdays = [.friday, .saturday, .sunday]
        }
        return s
    }

    // MARK: Firestore → LeagueSettings

    func parseLeagueSettings(from value: Any?) -> LeagueSettings {
        guard let data = value as? [String: Any] else { return .legacyDefaults }
        return normalizedSettings(LeagueSettings(
            visibility:                  LeagueVisibility(rawValue: data["visibility"]           as? String ?? "") ?? .privateLeague,
            maxParticipants:             data["maxParticipants"]                                  as? Int,
            allowedCompetitions:         (data["allowedCompetitions"]                             as? [String] ?? []).compactMap { LeagueCompetition(rawValue: $0) },
            betWindowPreset:             LeagueBetWindowPreset(rawValue: data["betWindowPreset"]  as? String ?? "") ?? .daily,
            activeWeekdays:              (data["activeWeekdays"]                                  as? [String] ?? []).compactMap { LeagueWeekday(rawValue: $0) },
            challengesOutsideBetWindow:  data["challengesOutsideBetWindow"]                       as? Bool   ?? true,
            initialBalance:              data["initialBalance"]                                   as? Int    ?? 100,
            betsPerActiveDay:            data["betsPerActiveDay"]                                 as? Int    ?? 3
        ))
    }

    // MARK: LeagueSettings → Firestore

    func leagueSettingsData(from settings: LeagueSettings) -> [String: Any] {
        let s = normalizedSettings(settings)
        var data: [String: Any] = [
            "visibility":                 s.visibility.rawValue,
            "allowedCompetitions":        s.allowedCompetitions.map(\.rawValue),
            "betWindowPreset":            s.betWindowPreset.rawValue,
            "activeWeekdays":             s.activeWeekdays.map(\.rawValue),
            "challengesOutsideBetWindow": s.challengesOutsideBetWindow,
            "initialBalance":             s.initialBalance,
            "betsPerActiveDay":           s.betsPerActiveDay
        ]
        if let max = s.maxParticipants { data["maxParticipants"] = max }
        return data
    }
}
