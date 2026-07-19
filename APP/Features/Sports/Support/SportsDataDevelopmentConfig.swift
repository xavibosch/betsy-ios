import Foundation

struct SportsDataDevelopmentConfig {
    static let modeLaunchArgument = "-BetsySportsDataMode"
    static let modeEnvironmentKey = "BETSY_SPORTS_DATA_MODE"
    static let modeUserDefaultsKey = "betsy.sportsDataMode"

    static var defaultMode: SportsDataMode {
        if let launchMode = modeFromLaunchArguments() {
            return launchMode
        }

        if let environmentMode = modeFromEnvironment() {
            return environmentMode
        }

        if let storedMode = modeFromUserDefaults() {
            return storedMode
        }

        return .real
    }

    private static func modeFromLaunchArguments() -> SportsDataMode? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: modeLaunchArgument), arguments.indices.contains(index + 1) else {
            return nil
        }
        return SportsDataMode(rawValue: arguments[index + 1].lowercased())
    }

    private static func modeFromEnvironment() -> SportsDataMode? {
        guard let value = ProcessInfo.processInfo.environment[modeEnvironmentKey]?.lowercased() else {
            return nil
        }
        return SportsDataMode(rawValue: value)
    }

    private static func modeFromUserDefaults() -> SportsDataMode? {
        guard let value = UserDefaults.standard.string(forKey: modeUserDefaultsKey)?.lowercased() else {
            return nil
        }
        return SportsDataMode(rawValue: value)
    }

    /// Call this when the user toggles dev mode so `APIManager` picks up the new mode on its next load.
    static func applyDevMode(_ enabled: Bool) {
        if enabled {
            UserDefaults.standard.set(SportsDataMode.fake.rawValue, forKey: modeUserDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: modeUserDefaultsKey)
        }
    }
}
