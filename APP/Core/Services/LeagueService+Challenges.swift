import FirebaseFirestore

// MARK: - 1v1 Match Challenges

extension LeagueService {

    func startChallenge(leagueId: String, opponentId: String, opponentName: String, wager: Int) {
        activeChallenge = ChallengeDraft(leagueId: leagueId, opponentId: opponentId,
                                         opponentName: opponentName, wager: wager)
    }

    func clearChallenge() {
        activeChallenge = nil
    }

    func createChallenge(leagueId: String, opponentId: String, opponentName: String,
                          match: Match, odd: Odd, wager: Int) {
        guard let uid = effectiveUserId else { return }
        let data: [String: Any] = [
            "leagueId":       leagueId,
            "challengerId":   uid,
            "challengerName": effectiveDisplayName,
            "opponentId":     opponentId,
            "opponentName":   opponentName,
            "matchHome":      match.home,
            "matchAway":      match.away,
            "selectionLabel": odd.label,
            "oddValue":       odd.value,
            "wager":          wager,
            "status":         "pending",
            "createdAt":      FieldValue.serverTimestamp()
        ]
        db.collection("leagues").document(leagueId).collection("challenges").addDocument(data: data) { [weak self] _ in
            self?.ensureOpponentInLeague(leagueId: leagueId, opponentId: opponentId, opponentName: opponentName)
        }
    }

    func listenForChallenges(leagueId: String) {
        challengeListener?.remove()
        challengeListener = db.collection("leagues").document(leagueId).collection("challenges")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = self.localized(
                            "No se pudieron cargar retos: \(error.localizedDescription)",
                            "Could not load challenges: \(error.localizedDescription)"
                        )
                    }
                    return
                }
                let items = snapshot?.documents.compactMap { doc -> Challenge? in
                    let data = doc.data()
                    return Challenge(
                        id:             doc.documentID,
                        leagueId:       data["leagueId"]       as? String ?? leagueId,
                        challengerId:   data["challengerId"]   as? String ?? "",
                        challengerName: data["challengerName"] as? String ?? "Challenger",
                        opponentId:     data["opponentId"]     as? String ?? "",
                        opponentName:   data["opponentName"]   as? String ?? "Opponent",
                        matchHome:      data["matchHome"]      as? String ?? "",
                        matchAway:      data["matchAway"]      as? String ?? "",
                        selectionLabel: data["selectionLabel"] as? String ?? "",
                        oddValue:       data["oddValue"]       as? Double ?? 0,
                        wager:          data["wager"]          as? Int    ?? 20,
                        status:         data["status"]         as? String ?? "pending",
                        createdAt:      (data["createdAt"] as? Timestamp)?.dateValue(),
                        winnerId:       data["winnerId"]       as? String,
                        loserId:        data["loserId"]        as? String
                    )
                } ?? []
                DispatchQueue.main.async { self.challengesByLeague[leagueId] = items }
            }
    }

    func resolvePendingChallengesRandomly(leagueId: String) {
        db.collection("leagues").document(leagueId).collection("challenges")
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, _ in
                guard let self else { return }
                for doc in snapshot?.documents ?? [] {
                    let data         = doc.data()
                    let challengerId = data["challengerId"] as? String ?? ""
                    let opponentId   = data["opponentId"]  as? String ?? ""
                    let winnerId     = Bool.random() ? challengerId : opponentId
                    let loserId      = winnerId == challengerId ? opponentId : challengerId
                    doc.reference.updateData([
                        "status":     "resolved",
                        "winnerId":   winnerId,
                        "loserId":    loserId,
                        "resolvedAt": FieldValue.serverTimestamp()
                    ])
                    let wager = data["wager"] as? Int ?? 20
                    self.transferPoints(leagueId: leagueId, winnerId: winnerId, loserId: loserId, amount: wager)
                }
            }
    }
}
