import Foundation

struct SportsDataProviderError: Error {
    let message: String
}

protocol SportsDataProvider: AnyObject {
    var mode: SportsDataMode { get }

    func cancelOddsRequests()
    func cancelLiveRequest()
    func cancelScoreRequests()

    func fetchOdds(
        for sport: String,
        completion: @escaping (Result<[Match], SportsDataProviderError>) -> Void
    )

    func fetchScores(
        for sport: String,
        completion: @escaping ([String: MatchScore]) -> Void
    )

    func fetchLiveMatches(
        leagueName: String,
        completion: @escaping (Result<[RapidMatch], SportsDataProviderError>) -> Void
    )

    func debugLeagues()
}
