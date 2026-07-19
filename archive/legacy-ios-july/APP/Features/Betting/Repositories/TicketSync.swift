import Foundation
import FirebaseFirestore

/// Mirrors a user's bets to Firestore so history survives reinstalls and syncs across
/// that user's devices. Firestore is the source of truth; the local UserDefaults cache
/// (TicketStore) stays as an offline mirror. Phase 1: settlement is still client-side and
/// writes back here. Phase 2 (Blaze + Cloud Function) flips `allow update` to server-only.
///
/// Path: leagues/{leagueId}/members/{uid}/tickets/{ticketId}
/// Each ticket is stored as a JSON payload string (UserTicket is Codable) plus a couple of
/// queryable fields — survives model changes without per-field mapping.
enum TicketSync {
    private static let db = Firestore.firestore()

    /// Scopes (leagueId|uid) this device has successfully pulled at least once. Until a scope
    /// is here, `push` upserts but does NOT prune remote orphans — otherwise a fresh install /
    /// new login that pushes (e.g. places a bet) before the async pull lands would delete the
    /// user's not-yet-downloaded history. Process-lifetime memory; safe to reset on relaunch
    /// because pull runs again on appear before the user can act.
    private static var pulledScopes = Set<String>()
    private static func scopeKey(_ leagueId: String, _ uid: String) -> String { "\(leagueId)|\(uid)" }

    private static func valid(_ leagueId: String, _ uid: String) -> Bool {
        !leagueId.isEmpty && !uid.isEmpty && leagueId != "no_league" && uid != "anonymous"
    }

    private static func collection(_ leagueId: String, _ uid: String) -> CollectionReference {
        db.collection("leagues").document(leagueId)
            .collection("members").document(uid)
            .collection("tickets")
    }

    /// Upsert this scope's tickets, then delete remote docs no longer present locally
    /// (keeps the 5-day placement prune in sync). Best-effort, fire-and-forget.
    static func push(tickets: [UserTicket], leagueId: String, uid: String) {
        guard valid(leagueId, uid) else { return }
        let ref = collection(leagueId, uid)
        let batch = db.batch()
        var localIds = Set<String>()

        for ticket in tickets {
            guard let data = try? JSONEncoder().encode(ticket),
                  let json = String(data: data, encoding: .utf8) else { continue }
            let id = ticket.id.uuidString
            localIds.insert(id)
            batch.setData([
                "payload": json,
                "isResultKnown": ticket.isResultKnown,
                "wasWon": ticket.wasWon,
                "date": Timestamp(date: ticket.date),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: ref.document(id), merge: true)
        }
        batch.commit { _ in }

        // Prune remote orphans (bets the local 5-day cleanup already dropped) — ONLY once this
        // device has pulled this scope, so we never delete history we simply haven't downloaded.
        guard pulledScopes.contains(scopeKey(leagueId, uid)) else { return }
        ref.getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let stale = docs.filter { !localIds.contains($0.documentID) }
            guard !stale.isEmpty else { return }
            let deleteBatch = db.batch()
            stale.forEach { deleteBatch.deleteDocument($0.reference) }
            deleteBatch.commit { _ in }
        }
    }

    /// Fetch this user's bets for a league. Completion on main.
    static func pull(leagueId: String, uid: String, completion: @escaping ([UserTicket]) -> Void) {
        guard valid(leagueId, uid) else { completion([]); return }
        collection(leagueId, uid).getDocuments { snapshot, error in
            // Mark scope pulled on any successful response (even empty) so push may prune safely.
            if error == nil { pulledScopes.insert(scopeKey(leagueId, uid)) }
            let tickets: [UserTicket] = (snapshot?.documents ?? []).compactMap { doc in
                guard let json = doc.data()["payload"] as? String,
                      let data = json.data(using: .utf8),
                      let ticket = try? JSONDecoder().decode(UserTicket.self, from: data) else { return nil }
                return ticket
            }
            DispatchQueue.main.async { completion(tickets) }
        }
    }
}
