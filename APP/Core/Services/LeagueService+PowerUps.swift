import FirebaseFirestore

// MARK: - Daily Power-Ups

extension LeagueService {

    func listenForPowerUps(leagueId: String, todayKey: String) {
        guard let uid = effectiveUserId else { return }
        powerUpListener?.remove()
        powerUpListener = db.collection("leagues").document(leagueId)
            .collection("members").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let data = snapshot?.data() else { return }
                let type    = data["dailyPowerUpType"] as? String ?? ""
                let date    = data["dailyPowerUpDate"] as? String ?? ""
                let used    = data["dailyPowerUpUsed"] as? Bool   ?? false
                let isToday = date == todayKey
                let multiplier = (isToday && !used && type == PowerUpType.multiplier.rawValue) ? 1 : 0
                let lifeline   = (isToday && !used && type == PowerUpType.lifeline.rawValue)   ? 1 : 0
                DispatchQueue.main.async {
                    self.myPowerUpsByLeague[leagueId] = PowerUpInventory(
                        multiplierCount: multiplier,
                        lifelineCount:   lifeline
                    )
                }
            }
    }

    func consumePowerUp(leagueId: String, type: PowerUpType, todayKey: String) {
        guard let uid = effectiveUserId else { return }
        db.collection("leagues").document(leagueId).collection("members").document(uid)
            .setData([
                "dailyPowerUpType": "",
                "dailyPowerUpDate": todayKey,
                "dailyPowerUpUsed": true
            ], merge: true)
    }

    func grantDailyPowerUpIfNeeded(leagueId: String, todayKey: String) {
        guard let uid = effectiveUserId else { return }
        let leagueRef = db.collection("leagues").document(leagueId)

        leagueRef.getDocument { [weak self] leagueSnap, _ in
            guard let self else { return }
            let leagueData = leagueSnap?.data() ?? [:]
            guard (leagueData["dailyPowerUpDate"] as? String ?? "") != todayKey else { return }

            leagueRef.collection("members").getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let yesterdayKey = self.previousDayKey(from: todayKey)
                var topId: String?
                var topPoints = -1
                for doc in docs {
                    let data   = doc.data()
                    let points = data["pointsToday"]    as? Int    ?? 0
                    let date   = data["pointsTodayDate"] as? String ?? ""
                    if date == yesterdayKey, points > topPoints {
                        topPoints = points
                        topId     = doc.documentID
                    }
                }

                guard let winnerId = topId, topPoints > 0 else {
                    leagueRef.setData(["dailyPowerUpDate": todayKey], merge: true)
                    return
                }

                let type    = Bool.random() ? PowerUpType.multiplier : .lifeline
                let typeRaw = type.rawValue
                leagueRef.setData([
                    "dailyPowerUpDate":   todayKey,
                    "dailyPowerUpWinner": winnerId,
                    "dailyPowerUpType":   typeRaw
                ], merge: true)
                leagueRef.collection("members").document(winnerId).setData([
                    "dailyPowerUpType": typeRaw,
                    "dailyPowerUpDate": todayKey,
                    "dailyPowerUpUsed": false
                ], merge: true)

                if winnerId == uid {
                    self.listenForPowerUps(leagueId: leagueId, todayKey: todayKey)
                }
            }
        }
    }
}
