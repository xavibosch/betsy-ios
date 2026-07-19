import Foundation

struct LocalAvatarStore: Codable {
    var byUserId: [String: Data]
}

enum ProfileAvatarStore {
    static func load(from data: Data) -> [String: Data] {
        guard !data.isEmpty else { return [:] }
        return (try? JSONDecoder().decode(LocalAvatarStore.self, from: data))?.byUserId ?? [:]
    }

    static func save(_ value: [String: Data]) -> Data {
        (try? JSONEncoder().encode(LocalAvatarStore(byUserId: value))) ?? Data()
    }
}
