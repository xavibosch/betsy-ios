import Foundation

struct DeveloperDaySummary: Codable {
    var dayKey: String
    var leagueId: String
    var leagueName: String
    var wonTickets: Int
    var lostTickets: Int
    var withdrawnTickets: Int
    var resolvedTickets: Int
    var netPoints: Int
    var resultingBalance: Int
    var remainingOpenTickets: Int
    var recoveryAvailable: Bool
    var dailySlotsResetTo: Int
    var didResetArenaState: Bool
}
