import Foundation

final class SportsDataRepository {
    private let realProvider: any SportsDataProvider
    private let fakeProvider: FakeSportsDataProvider
    private(set) var mode: SportsDataMode
    private(set) var simulationSettings: SportsSimulationSettings

    init(
        mode: SportsDataMode = SportsDataDevelopmentConfig.defaultMode,
        simulationSettings: SportsSimulationSettings = .default,
        realProvider: (any SportsDataProvider)? = nil,
        fakeProvider: FakeSportsDataProvider? = nil
    ) {
        self.mode = mode
        self.simulationSettings = simulationSettings
        self.realProvider = realProvider ?? RealSportsDataProvider()
        self.fakeProvider = fakeProvider ?? FakeSportsDataProvider(simulationSettings: simulationSettings)
    }

    func setMode(_ mode: SportsDataMode) {
        self.mode = mode
    }

    func updateSimulationSettings(_ settings: SportsSimulationSettings) {
        simulationSettings = settings
        fakeProvider.updateSimulationSettings(settings)
    }

    func cancelOddsRequests() {
        realProvider.cancelOddsRequests()
        fakeProvider.cancelOddsRequests()
    }

    func cancelLiveRequest() {
        realProvider.cancelLiveRequest()
        fakeProvider.cancelLiveRequest()
    }

    func cancelScoreRequests() {
        realProvider.cancelScoreRequests()
        fakeProvider.cancelScoreRequests()
    }

    func fetchOdds(
        for sport: String,
        completion: @escaping (Result<[Match], SportsDataProviderError>) -> Void
    ) {
        activeProvider.fetchOdds(for: sport, completion: completion)
    }

    func fetchScores(
        for sport: String,
        completion: @escaping ([String: MatchScore]) -> Void
    ) {
        activeProvider.fetchScores(for: sport, completion: completion)
    }

    func fetchLiveMatches(
        leagueName: String,
        completion: @escaping (Result<[RapidMatch], SportsDataProviderError>) -> Void
    ) {
        activeProvider.fetchLiveMatches(leagueName: leagueName, completion: completion)
    }

    func debugLeagues() {
        activeProvider.debugLeagues()
    }

    private var activeProvider: any SportsDataProvider {
        mode == .fake ? fakeProvider : realProvider
    }
}
