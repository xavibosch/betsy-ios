import Foundation
import UserNotifications

/// Schedules local notifications for Betsy.
///
/// - **Reminder**: one daily notification at the user's chosen time,
///   telling them how many bets they have left in their league.
/// - **Engagement**: three motivational notifications spread through
///   the day (10:00, 14:00 and 20:30) to keep users active.
enum BetReminderScheduler {

    // MARK: - Identifiers

    static let reminderIdentifier  = "betsy.daily.bet.reminder"
    static let engagementPrefix    = "betsy.engagement."
    static let engagementTimes: [(hour: Int, minute: Int)] = [
        (10, 0),
        (14, 0),
        (20, 30)
    ]

    // MARK: - Authorization

    static func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func currentAuthorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // MARK: - Cancel

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    static func cancelEngagement() {
        let ids = engagementTimes.indices.map { "\(engagementPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func cancelAll() {
        cancel()
        cancelEngagement()
    }

    // MARK: - Arena challenge notification

    static func notifyChallengeInvite(challengerName: String, wager: Int, leagueName: String?) {
        let lang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "es"
        requestAuthorization { granted in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            if lang == "en" {
                content.title = "Arena challenge received"
                content.body = "\(challengerName) challenged you for \(wager) pts\(leagueName.map { " in \($0)" } ?? "")."
            } else {
                content.title = "Reto Arena recibido"
                content.body = "\(challengerName) te ha retado por \(wager) pts\(leagueName.map { " en \($0)" } ?? "")."
            }
            content.sound = .default
            content.threadIdentifier = "betsy.arena.challenge"

            let request = UNNotificationRequest(
                identifier: "betsy.arena.challenge.\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("[BetReminderScheduler] challenge notification failed: \(error.localizedDescription)") }
            }
        }
    }

    static func notifyArenaResult(didWin: Bool, points: Int, rivalName: String) {
        let lang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "es"
        requestAuthorization { granted in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            if lang == "en" {
                content.title = didWin ? "Arena challenge won" : "Arena challenge lost"
                content.body = didWin ? "You beat \(rivalName) and won \(points) pts." : "\(rivalName) won this Arena challenge."
            } else {
                content.title = didWin ? "Has ganado el reto" : "Has perdido el reto"
                content.body = didWin ? "Has ganado contra \(rivalName): +\(points) pts." : "\(rivalName) ganó este reto Arena."
            }
            content.sound = .default
            content.threadIdentifier = "betsy.arena.result"

            let request = UNNotificationRequest(
                identifier: "betsy.arena.result.\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("[BetReminderScheduler] arena result notification failed: \(error.localizedDescription)") }
            }
        }
    }

    // MARK: - Bet reminder (user-chosen time)

    /// Schedule (or cancel) the daily bet reminder.
    static func schedule(
        enabled: Bool,
        hour: Int,
        minute: Int,
        leagueName: String?,
        betsLeftToday: Int,
        dailyLimit: Int,
        isWithinBetWindow: Bool
    ) {
        cancel()
        guard enabled, let leagueName else { return }
        let lang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "es"

        let content = UNMutableNotificationContent()
        content.title = reminderTitle(
            betsLeft: betsLeftToday,
            limit: dailyLimit,
            withinWindow: isWithinBetWindow,
            league: leagueName,
            lang: lang
        )
        content.body = reminderBody(
            betsLeft: betsLeftToday,
            limit: dailyLimit,
            withinWindow: isWithinBetWindow,
            lang: lang
        )
        content.sound = .default
        content.threadIdentifier = reminderIdentifier

        var components = DateComponents()
        components.hour   = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[BetReminderScheduler] reminder failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Engagement notifications (3 per day)

    /// Schedule (or cancel) the three daily engagement notifications.
    static func scheduleEngagement(
        enabled: Bool,
        leagueName: String?,
        pendingBets: Int,
        lang: String = "es"
    ) {
        cancelEngagement()
        guard enabled, let league = leagueName else { return }

        let messages = engagementMessages(league: league, pendingBets: pendingBets, lang: lang)

        for (index, time) in engagementTimes.enumerated() {
            let content = UNMutableNotificationContent()
            let msg = messages[index % messages.count]
            content.title = msg.title
            content.body  = msg.body
            content.sound = .default
            content.threadIdentifier = "\(engagementPrefix)\(index)"

            var components = DateComponents()
            components.hour   = time.hour
            components.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(engagementPrefix)\(index)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("[BetReminderScheduler] engagement[\(index)] failed: \(error.localizedDescription)") }
            }
        }
    }

    // MARK: - Message pools

    private struct NotifMessage { let title: String; let body: String }

    private static func engagementMessages(league: String, pendingBets: Int, lang: String) -> [NotifMessage] {
        if lang == "en" {
            return [
                NotifMessage(
                    title: "⚡ \(league) is moving",
                    body: pendingBets > 0
                        ? "You still have \(pendingBets) bet\(pendingBets == 1 ? "" : "s") to place. Don't fall behind."
                        : "Check the leaderboard — the ranking shifts fast."
                ),
                NotifMessage(
                    title: "🏆 Climb the table",
                    body: "One good pick changes everything. Open Betsy and make your move."
                ),
                NotifMessage(
                    title: "⚔️ Arena waiting",
                    body: "Challenge a friend to a 1v1 duel and take their points. No mercy."
                )
            ]
        }
        // Spanish (default)
        return [
            NotifMessage(
                title: "⚡ \(league) está en marcha",
                body: pendingBets > 0
                    ? "Aún te quedan \(pendingBets) apuesta\(pendingBets == 1 ? "" : "s"). No dejes que la liga avance sin ti."
                    : "Revisa la clasificación — el ranking se mueve rápido."
            ),
            NotifMessage(
                title: "🏆 Sube en la tabla",
                body: "Un buen pick lo cambia todo. Abre Betsy y no dejes pasar la jornada."
            ),
            NotifMessage(
                title: "⚔️ Arena te espera",
                body: "Reta a alguien a un duelo 1v1 y quédate con sus puntos. Sin piedad."
            )
        ]
    }

    // MARK: - Reminder copy

    private static func reminderTitle(betsLeft: Int, limit: Int, withinWindow: Bool, league: String, lang: String) -> String {
        if lang == "en" {
            if !withinWindow { return "👀 \(league) is moving" }
            if limit <= 0    { return "⚙️ Set up your league" }
            if betsLeft <= 0 { return "🌙 Day closed · \(league)" }
            if betsLeft == limit { return "🔥 \(league): new matchday" }
            if betsLeft == 1     { return "⚡ Last shot · \(league)" }
            return "🎯 \(league): \(betsLeft) left"
        }
        if !withinWindow { return "👀 \(league) en marcha" }
        if limit <= 0    { return "⚙️ Ajusta tu liga" }
        if betsLeft <= 0 { return "🌙 Día cerrado · \(league)" }
        if betsLeft == limit { return "🔥 \(league): jornada nueva" }
        if betsLeft == 1     { return "⚡ Última bala · \(league)" }
        return "🎯 \(league): te \(betsLeft == 1 ? "queda" : "quedan") \(betsLeft)"
    }

    private static func reminderBody(betsLeft: Int, limit: Int, withinWindow: Bool, lang: String) -> String {
        if lang == "en" {
            if !withinWindow {
                return "Your league rests today. The ranking still moves — check how it is going."
            }
            if limit <= 0 {
                return "Your league has no bets configured. Tap to review it."
            }
            if betsLeft <= 0 {
                return "You're done for today. Tomorrow we go again."
            }
            if betsLeft == limit {
                if limit == 1 { return "You have 1 fresh pick waiting. Make it count." }
                return "\(limit) fresh bets are on the table. Start strong."
            }
            if betsLeft == 1 {
                return "Only 1 pick left. The one that can decide the day."
            }
            return "You have \(betsLeft) bets left today. Don't let the league move without you."
        }
        if !withinWindow {
            return "Hoy descansa la liga. Pero el ranking se mueve — pásate a ver cómo va."
        }
        if limit <= 0 {
            return "Tu liga no tiene apuestas configuradas. Toca para revisarlo."
        }
        if betsLeft <= 0 {
            return "Hoy ya está. Mañana volvemos al ataque."
        }
        if betsLeft == limit {
            if limit == 1 { return "Tienes 1 pick fresco esperando. Hazla contar." }
            return "\(limit) apuestas frescas en tu mesa. Empieza fuerte y déjales atrás."
        }
        if betsLeft == 1 {
            return "Solo te queda 1 pick. La que decide la jornada. ¿Te la juegas?"
        }
        return "Te quedan \(betsLeft) apuestas hoy. No dejes que la liga avance sin ti."
    }
}
