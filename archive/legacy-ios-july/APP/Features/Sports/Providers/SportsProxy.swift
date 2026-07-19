import Foundation
import FirebaseAppCheck

/// Single choke-point for every paid sports-API call.
///
/// Two modes, switched by `useProxy`:
///
///  • `useProxy = true`  → routes through our Cloud Function (`apiProxy`). The API keys
///    live ONLY as Function secrets on the server; the app carries none. Each request is
///    stamped with a Firebase App Check token so the proxy can prove the caller is a
///    genuine instance of this app before spending a key. **This is the secure mode.**
///    Requires the Firebase project on the Blaze plan (Cloud Functions + Secret Manager).
///
///  • `useProxy = false` → legacy direct calls with the key from `APISecrets` (key ships
///    in the binary). Used only until the backend is on Blaze and `apiProxy` is deployed.
///
/// To go secure: deploy `apiProxy`, set the secrets, then flip `useProxy` to `true`.
enum SportsProxy {

    /// ⚠️ Flip to `true` once `apiProxy` is deployed (needs Blaze plan) to move keys server-side.
    static let useProxy = false

    /// europe-west1 · project betsy-9b8cf — the deployed `apiProxy` HTTPS function.
    static let base = "https://europe-west1-betsy-9b8cf.cloudfunctions.net/apiProxy"

    enum Upstream: String {
        case odds
        case rapidlive
        case footballdata
        case apisports

        var host: String {
            switch self {
            case .odds:         return "api.the-odds-api.com"
            case .rapidlive:    return "free-api-live-football-data.p.rapidapi.com"
            case .footballdata: return "api.football-data.org"
            case .apisports:    return "v3.football.api-sports.io"
            }
        }
    }

    /// Build the request URL for `path` (upstream path, e.g. "/v4/sports/soccer_epl/odds/").
    static func url(_ upstream: Upstream, path: String, query: [String: String] = [:]) -> URL? {
        if useProxy {
            var comps = URLComponents(string: base)
            var items = [
                URLQueryItem(name: "__u", value: upstream.rawValue),
                URLQueryItem(name: "__p", value: path)
            ]
            for (k, v) in query { items.append(URLQueryItem(name: k, value: v)) }
            comps?.queryItems = items
            return comps?.url
        }

        // Direct mode — hit the provider straight, key injected in `authorize`.
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = upstream.host
        comps.path = path
        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        if upstream == .odds {
            items.append(URLQueryItem(name: "apiKey", value: OddsKeyRing.shared.currentKey))
        }
        comps.queryItems = items.isEmpty ? nil : items
        return comps.url
    }

    /// Attach auth (App Check token in proxy mode; provider key headers in direct mode)
    /// and hand back a ready-to-fire request.
    static func authorize(
        _ url: URL,
        _ upstream: Upstream,
        timeout: TimeInterval = 10,
        cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad,
        completion: @escaping (URLRequest) -> Void
    ) {
        var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)

        if useProxy {
            AppCheck.appCheck().token(forcingRefresh: false) { token, _ in
                if let token { request.addValue(token.token, forHTTPHeaderField: "X-Firebase-AppCheck") }
                completion(request)
            }
            return
        }

        // Direct mode — set the provider's key headers (odds key already in the URL query).
        switch upstream {
        case .odds:
            break
        case .rapidlive:
            request.addValue(APISecrets.rapidApiKey, forHTTPHeaderField: "x-rapidapi-key")
            request.addValue("free-api-live-football-data.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        case .footballdata:
            request.addValue(APISecrets.footballDataKey, forHTTPHeaderField: "X-Auth-Token")
        case .apisports:
            request.addValue(APISecrets.apiSportsKey, forHTTPHeaderField: "x-apisports-key")
        }
        completion(request)
    }
}
