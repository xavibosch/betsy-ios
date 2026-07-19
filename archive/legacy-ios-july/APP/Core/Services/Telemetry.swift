import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

/// Single entry point for analytics + crash reporting.
/// - Analytics only fires when the user gave GDPR consent (`gdprAnalyticsConsent`).
/// - Crashlytics auto-collects crashes once the SDK is linked + Firebase configured;
///   here we add a few non-fatal/log helpers and tie reports to the current user.
enum Telemetry {

    /// Firebase only exists when GoogleService-Info.plist is bundled (not in pure dev mode).
    private static var ready: Bool { FirebaseApp.app() != nil }

    // MARK: Consent

    /// Apply the user's analytics choice. Call on launch and whenever consent changes.
    static func applyConsent() {
        guard ready else { return }
        let consent = UserDefaults.standard.bool(forKey: "gdprAnalyticsConsent")
        Analytics.setAnalyticsCollectionEnabled(consent)
    }

    // MARK: Analytics events  (no-ops when collection is disabled)

    static func log(_ name: String, _ params: [String: Any] = [:]) {
        guard ready else { return }
        Analytics.logEvent(name, parameters: params.isEmpty ? nil : params)
    }

    static func signedUp()                 { log("sign_up") }
    static func loggedIn()                 { log("login") }
    static func leagueCreated()            { log("league_created") }
    static func leagueJoined()             { log("league_joined") }
    static func betPlaced(picks: Int, stake: Int) {
        log("bet_placed", ["picks": picks, "stake": stake])
    }
    static func arenaCreated(wager: Int)   { log("arena_created", ["wager": wager]) }
    static func betSettled(won: Bool)      { log("bet_settled", ["won": won]) }

    // MARK: Crashlytics

    /// Attach the current user id to crash reports (helps trace a friend's crash).
    static func setUser(_ uid: String?) {
        guard ready else { return }
        Crashlytics.crashlytics().setUserID(uid ?? "anonymous")
    }

    /// Record a handled (non-fatal) error so it shows in the Crashlytics dashboard.
    static func record(_ error: Error, context: String = "") {
        guard ready else { return }
        if !context.isEmpty {
            Crashlytics.crashlytics().log(context)
        }
        Crashlytics.crashlytics().record(error: error)
    }
}
