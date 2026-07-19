import Foundation
import FirebaseFirestore

// MARK: - Arena Duels

extension LeagueService {

    fileprivate func arenaPayout(wager: Int, selections: [ArenaBetSelection]) -> Int {
        max(1, Int((Double(wager) * arenaCombinedOdds(selections)).rounded()))
    }

    fileprivate func arenaNetProfit(wager: Int, selections: [ArenaBetSelection]) -> Int {
        max(arenaPayout(wager: wager, selections: selections) - wager, 0)
    }

    fileprivate func arenaCombinedOdds(_ selections: [ArenaBetSelection]) -> Double {
        selections.reduce(1.0) { $0 * $1.oddValue }
    }

    // MARK: Listener

    func listenForArena(leagueId: String) {
        guard let uid = effectiveUserId else { return }
        arenaListener?.remove()

        if isDevModeActive {
            arenaListener = nil
            refreshDevArenaState(leagueId: leagueId, uid: uid)
            return
        }

        arenaListener = db.collection("leagues").document(leagueId).collection("arenas")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = self.localized(
                            "No se pudieron cargar duelos: \(error.localizedDescription)",
                            "Could not load duels: \(error.localizedDescription)"
                        )
                    }
                    return
                }
                let items    = snapshot?.documents.compactMap { self.parseArenaDuel(doc: $0) } ?? []
                let pending  = items.first { $0.status == "pending"  && $0.opponentId   == uid }
                let outgoing = items.first { $0.status == "pending"  && $0.challengerId  == uid }
                let declined = items.first { $0.status == "declined" && $0.challengerId  == uid }
                let active   = items.first { $0.status == "active"   && ($0.challengerId == uid || $0.opponentId == uid) }
                DispatchQueue.main.async {
                    self.arenasByLeague[leagueId] = items
                    self.pendingArenaInvite  = pending
                    self.outgoingArenaInvite = outgoing
                    self.declinedArenaInvite = declined
                    self.activeArena         = active
                }
            }
    }

    // MARK: Create

    func createArenaDuel(
        leagueId: String,
        opponentId: String,
        opponentName: String,
        wager: Int,
        matches: [ArenaMatch],
        challengerSelections: [ArenaBetSelection] = []
    ) {
        guard let uid = effectiveUserId else { return }
        errorMessage = nil
        let today          = todayKey()
        let challengerName = effectiveDisplayName

        if isDevModeActive {
            let store = DevDataStore.shared
            if store.arenaChallengeDay(userId: uid) == today {
                errorMessage = localized("Solo puedes iniciar 1 reto al día.", "You can only start 1 challenge per day.")
                return
            }
            let initialBalance = myLeagues.first(where: { $0.id == leagueId })?.settings.initialBalance ?? 1000
            store.adjustPoints(leagueId: leagueId, userId: uid, initialBalance: initialBalance, delta: -wager, todayKey: today)
            let duelId = UUID().uuidString
            let localDuel = ArenaDuel(
                id: duelId, leagueId: leagueId,
                challengerId: uid, challengerName: challengerName,
                opponentId: opponentId, opponentName: opponentName,
                wager: wager, status: "pending", createdAt: Date(),
                matches: matches, challengerSelections: challengerSelections,
                opponentSelections: [], winnerId: nil, loserId: nil
            )
            store.setArenaChallengeDay(userId: uid, day: today)
            store.insertArena(localDuel, leagueId: leagueId)
            ensureOpponentInLeague(leagueId: leagueId, opponentId: opponentId, opponentName: opponentName)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.outgoingArenaInvite = localDuel
                self.refreshDevArenaState(leagueId: leagueId, uid: uid)
            }
            return
        }

        let userRef              = db.collection("users").document(uid)
        let challengerMemberRef  = db.collection("leagues").document(leagueId).collection("members").document(uid)
        let arenasRef            = db.collection("leagues").document(leagueId).collection("arenas")
        let duelRef              = arenasRef.document()
        let matchesPayload       = matches.map { arenaMatchToDict($0) }
        let challengerSelPayload = challengerSelections.map { arenaSelectionToDict($0) }

        let localDuel = ArenaDuel(
            id: duelRef.documentID, leagueId: leagueId,
            challengerId: uid, challengerName: challengerName,
            opponentId: opponentId, opponentName: opponentName,
            wager: wager, status: "pending", createdAt: Date(),
            matches: matches, challengerSelections: challengerSelections,
            opponentSelections: [], winnerId: nil, loserId: nil
        )

        var data: [String: Any] = [
            "leagueId":       leagueId,
            "challengerId":   uid,
            "challengerName": challengerName,
            "opponentId":     opponentId,
            "opponentName":   opponentName,
            "wager":          wager,
            "status":         "pending",
            "matches":        matchesPayload,
            "createdAtClient": Timestamp(date: Date()),
            "createdAt":      FieldValue.serverTimestamp()
        ]
        if !challengerSelPayload.isEmpty { data["challengerSelections"] = challengerSelPayload }

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let userSnap = try transaction.getDocument(userRef)
                let memberSnap = try transaction.getDocument(challengerMemberRef)
                let lastDay  = userSnap.data()?["arenaChallengeDay"] as? String ?? ""
                if lastDay == today {
                    errorPointer?.pointee = NSError(
                        domain: "ArenaDailyLimit", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: self.localized(
                            "Solo puedes iniciar 1 reto al día.",
                            "You can only start 1 challenge per day."
                        )]
                    )
                    return nil
                }
                let key = self.todayKey()
                let current = memberSnap.data()?["points"] as? Int ?? 0
                let todayPoints = memberSnap.data()?["pointsToday"] as? Int ?? 0
                let todayDate = memberSnap.data()?["pointsTodayDate"] as? String ?? ""
                transaction.setData([
                    "name": challengerName,
                    "points": current - wager,
                    "pointsToday": (todayDate == key ? todayPoints : 0) - wager,
                    "pointsTodayDate": key,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: challengerMemberRef, merge: true)
                transaction.setData(["arenaChallengeDay": today, "updatedAt": FieldValue.serverTimestamp()],
                                    forDocument: userRef, merge: true)
                transaction.setData(data, forDocument: duelRef, merge: false)
                return nil
            } catch let error as NSError { errorPointer?.pointee = error; return nil }
        }) { [weak self] _, error in
            if let error {
                DispatchQueue.main.async { self?.errorMessage = error.localizedDescription }
            } else {
                DispatchQueue.main.async {
                    self?.outgoingArenaInvite = localDuel
                    var duels = self?.arenasByLeague[leagueId] ?? []
                    if !duels.contains(where: { $0.id == localDuel.id }) { duels.insert(localDuel, at: 0) }
                    self?.arenasByLeague[leagueId] = duels
                }
                self?.ensureOpponentInLeague(leagueId: leagueId, opponentId: opponentId, opponentName: opponentName)
            }
        }
    }

    /// Adds the opponent to the league so `listenForLeagues` surfaces the
    /// league on their device and the pending invite is delivered.
    func ensureOpponentInLeague(leagueId: String, opponentId: String, opponentName: String) {
        guard !opponentId.isEmpty else { return }

        if isDevModeActive {
            ensureOpponentInDevLeague(leagueId: leagueId, opponentId: opponentId, opponentName: opponentName)
            return
        }

        let leagueRef = db.collection("leagues").document(leagueId)
        let memberRef = leagueRef.collection("members").document(opponentId)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let leagueSnap = try transaction.getDocument(leagueRef)
                var members    = leagueSnap.data()?["members"] as? [String] ?? []
                if !members.contains(opponentId) {
                    members.append(opponentId)
                    transaction.updateData(["members": members, "membersCount": members.count], forDocument: leagueRef)
                }
                let memberSnap = try transaction.getDocument(memberRef)
                let settings   = self.parseLeagueSettings(from: leagueSnap.data()?["settings"])
                if !memberSnap.exists {
                    transaction.setData([
                        "name":              opponentName,
                        "points":            settings.initialBalance,
                        "pointsToday":       0,
                        "pointsTodayDate":   "",
                        "recoveryBoostDate": "",
                        "dailyPowerUpType":  "",
                        "dailyPowerUpDate":  "",
                        "dailyPowerUpUsed":  false,
                        "updatedAt":         FieldValue.serverTimestamp()
                    ], forDocument: memberRef, merge: false)
                } else {
                    transaction.setData(["name": opponentName, "updatedAt": FieldValue.serverTimestamp()],
                                        forDocument: memberRef, merge: true)
                }
                return nil
            } catch let error as NSError { errorPointer?.pointee = error; return nil }
        }) { _, _ in }
    }

    // MARK: Accept / Decline / Delete

    func acceptArena(duelId: String, leagueId: String, completion: ((Bool) -> Void)? = nil) {
        guard let uid = effectiveUserId else { completion?(false); return }

        if isDevModeActive {
            let store = DevDataStore.shared
            let duels = store.arenas(leagueId: leagueId)
            guard let i = duels.firstIndex(where: { $0.id == duelId }) else { completion?(false); return }
            let duel = duels[i]
            guard duel.status == "pending" else {
                DispatchQueue.main.async {
                    self.errorMessage = self.localized("Este duelo ya no está pendiente.", "This duel is no longer pending.")
                    completion?(false)
                }
                return
            }
            let initialBalance = myLeagues.first(where: { $0.id == leagueId })?.settings.initialBalance ?? 1000
            let key = todayKey()
            // Challenger stake was locked when creating the challenge; opponent locks stake on accept.
            store.adjustPoints(leagueId: leagueId, userId: uid, initialBalance: initialBalance, delta: -duel.wager, todayKey: key)
            // Update duel status
            let updated = ArenaDuel(
                id: duel.id, leagueId: duel.leagueId,
                challengerId: duel.challengerId, challengerName: duel.challengerName,
                opponentId: duel.opponentId, opponentName: duel.opponentName,
                wager: duel.wager, status: "active", createdAt: duel.createdAt,
                matches: duel.matches,
                challengerSelections: duel.challengerSelections,
                opponentSelections: duel.opponentSelections,
                winnerId: nil, loserId: nil
            )
            store.updateArena(updated, leagueId: leagueId)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let league = self.myLeagues.first(where: { $0.id == leagueId }) {
                    self.loadDeveloperMembers(for: league)
                }
                self.refreshDevArenaState(leagueId: leagueId, uid: uid)
                completion?(true)
            }
            return
        }

        let leagueRef   = db.collection("leagues").document(leagueId)
        let duelRef     = leagueRef.collection("arenas").document(duelId)
        let opponentRef = leagueRef.collection("members").document(uid)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let duelSnap      = try transaction.getDocument(duelRef)
                let duelData      = duelSnap.data() ?? [:]
                let status        = duelData["status"]       as? String ?? "pending"
                let wager         = max(duelData["wager"]    as? Int    ?? 0, 0)
                let opponentSnap   = try transaction.getDocument(opponentRef)

                if status != "pending" {
                    errorPointer?.pointee = NSError(
                        domain: "ArenaState", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: self.localized(
                            "Este duelo ya no está pendiente.",
                            "This duel is no longer pending."
                        )]
                    )
                    return nil
                }

                let key               = self.todayKey()
                let opponentPoints    = opponentSnap.data()?["points"]            as? Int    ?? 0
                let opponentToday     = opponentSnap.data()?["pointsToday"]       as? Int    ?? 0
                let opponentTodayDt   = opponentSnap.data()?["pointsTodayDate"]   as? String ?? ""

                transaction.updateData([
                    "points":          opponentPoints - wager,
                    "pointsToday":     (opponentTodayDt == key ? opponentToday : 0) - wager,
                    "pointsTodayDate": key,
                    "updatedAt":       FieldValue.serverTimestamp()
                ], forDocument: opponentRef)

                transaction.updateData([
                    "status":     "active",
                    "acceptedAt": FieldValue.serverTimestamp()
                ], forDocument: duelRef)
                return true
            } catch let error as NSError { errorPointer?.pointee = error; return nil }
        }) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error { self?.errorMessage = error.localizedDescription; completion?(false) }
                else {
                    if let league = self?.myLeagues.first(where: { $0.id == leagueId }) {
                        self?.loadMembers(for: league)
                    }
                    completion?((result as? Bool) ?? false)
                }
            }
        }
    }

    func declineArena(duelId: String, leagueId: String) {
        if isDevModeActive {
            guard let uid = effectiveUserId else { return }
            let store = DevDataStore.shared
            let duels = store.arenas(leagueId: leagueId)
            guard let i = duels.firstIndex(where: { $0.id == duelId }) else { return }
            let duel = duels[i]
            let updated = ArenaDuel(
                id: duel.id, leagueId: duel.leagueId,
                challengerId: duel.challengerId, challengerName: duel.challengerName,
                opponentId: duel.opponentId, opponentName: duel.opponentName,
                wager: duel.wager, status: "declined", createdAt: duel.createdAt,
                matches: duel.matches,
                challengerSelections: duel.challengerSelections,
                opponentSelections: duel.opponentSelections,
                winnerId: nil, loserId: nil
            )
            store.updateArena(updated, leagueId: leagueId)
            let initialBalance = myLeagues.first(where: { $0.id == leagueId })?.settings.initialBalance ?? 1000
            store.adjustPoints(leagueId: leagueId, userId: duel.challengerId, initialBalance: initialBalance, delta: duel.wager, todayKey: todayKey())
            refreshDevArenaState(leagueId: leagueId, uid: uid)
            return
        }
        db.collection("leagues").document(leagueId).collection("arenas").document(duelId)
            .updateData(["status": "declined", "declinedAt": FieldValue.serverTimestamp()]) { [weak self] _ in
                guard let self,
                      let duel = self.arenasByLeague[leagueId]?.first(where: { $0.id == duelId })
                else { return }
                self.adjustPoints(leagueId: leagueId, delta: duel.wager, forUserId: duel.challengerId, displayName: duel.challengerName)
            }
    }

    func deleteArena(duelId: String, leagueId: String) {
        if isDevModeActive {
            guard let uid = effectiveUserId else { return }
            DevDataStore.shared.removeArena(duelId: duelId, leagueId: leagueId)
            refreshDevArenaState(leagueId: leagueId, uid: uid)
            return
        }
        db.collection("leagues").document(leagueId).collection("arenas").document(duelId).delete()
    }

    // MARK: Selections

    func submitArenaSelection(duel: ArenaDuel, selections: [ArenaBetSelection]) {
        guard let uid = effectiveUserId else { return }

        if isDevModeActive {
            let store = DevDataStore.shared
            let isChallenger = uid == duel.challengerId
            let updated = ArenaDuel(
                id: duel.id, leagueId: duel.leagueId,
                challengerId: duel.challengerId, challengerName: duel.challengerName,
                opponentId: duel.opponentId, opponentName: duel.opponentName,
                wager: duel.wager, status: duel.status, createdAt: duel.createdAt,
                matches: duel.matches,
                challengerSelections: isChallenger ? selections : duel.challengerSelections,
                opponentSelections:   isChallenger ? duel.opponentSelections : selections,
                winnerId: duel.winnerId, loserId: duel.loserId
            )
            store.updateArena(updated, leagueId: duel.leagueId)
            refreshDevArenaState(leagueId: duel.leagueId, uid: uid)
            return
        }

        let ref           = db.collection("leagues").document(duel.leagueId).collection("arenas").document(duel.id)
        let selectionData = selections.map { [
            "matchId":  $0.matchId,
            "home":     $0.home,
            "away":     $0.away,
            "oddLabel": $0.oddLabel,
            "oddValue": $0.oddValue
        ] as [String: Any] }

        if uid == duel.challengerId    { ref.updateData(["challengerSelections": selectionData]) }
        else if uid == duel.opponentId { ref.updateData(["opponentSelections":  selectionData]) }
    }

    // MARK: Dev resolution (also works in dev mode — pure local)

    func resolveArenaDuelsRandomly(leagueId: String) {
        if isDevModeActive {
            let store = DevDataStore.shared
            let items = store.arenas(leagueId: leagueId)
            for duel in items where duel.status == "active" {
                let cSel = duel.challengerSelections
                let oSel = duel.opponentSelections
                guard !cSel.isEmpty, !oSel.isEmpty else { continue }

                let cWins = cSel.map { _ in Bool.random() }
                let oWins = oSel.map { _ in Bool.random() }
                let cCorrect = cWins.filter { $0 }.count
                let oCorrect = oWins.filter { $0 }.count
                let cOdds = arenaCombinedOdds(cSel)
                let oOdds = arenaCombinedOdds(oSel)
                let cPayout = arenaPayout(wager: duel.wager, selections: cSel)
                let oPayout = arenaPayout(wager: duel.wager, selections: oSel)
                let cDuelWon: Bool
                let oDuelWon: Bool

                var winnerId: String?
                var loserId:  String?
                if cCorrect == cSel.count, oCorrect == oSel.count, cSel.count == oSel.count {
                    cDuelWon = true
                    oDuelWon = true
                    winnerId = "both"
                } else if cCorrect > oCorrect {
                    cDuelWon = true
                    oDuelWon = false
                    winnerId = duel.challengerId; loserId = duel.opponentId
                } else if oCorrect > cCorrect {
                    cDuelWon = false
                    oDuelWon = true
                    winnerId = duel.opponentId;   loserId = duel.challengerId
                } else if cOdds > oOdds {
                    cDuelWon = true
                    oDuelWon = false
                    winnerId = duel.challengerId; loserId = duel.opponentId
                } else if oOdds > cOdds {
                    cDuelWon = false
                    oDuelWon = true
                    winnerId = duel.opponentId;   loserId = duel.challengerId
                } else {
                    cDuelWon = false
                    oDuelWon = false
                }

                let resolved = ArenaDuel(
                    id: duel.id, leagueId: duel.leagueId,
                    challengerId: duel.challengerId, challengerName: duel.challengerName,
                    opponentId: duel.opponentId, opponentName: duel.opponentName,
                    wager: duel.wager, status: "resolved", createdAt: duel.createdAt,
                    matches: duel.matches,
                    challengerSelections: duel.challengerSelections,
                    opponentSelections: duel.opponentSelections,
                    winnerId: winnerId, loserId: loserId
                )
                store.updateArena(resolved, leagueId: leagueId)

                if cDuelWon {
                    adjustPoints(leagueId: leagueId, delta: cPayout, forUserId: duel.challengerId, displayName: duel.challengerName)
                }
                if oDuelWon {
                    adjustPoints(leagueId: leagueId, delta: oPayout, forUserId: duel.opponentId, displayName: duel.opponentName)
                }
                recordArenaResultTicket(duel: duel, userId: duel.challengerId, rivalName: duel.opponentName, selections: cSel, didWin: cDuelWon)
                recordArenaResultTicket(duel: duel, userId: duel.opponentId, rivalName: duel.challengerName, selections: oSel, didWin: oDuelWon)

                if let uid = effectiveUserId, uid == duel.challengerId || uid == duel.opponentId {
                    let didWin = uid == duel.challengerId ? cDuelWon : oDuelWon
                    let net = uid == duel.challengerId ? arenaNetProfit(wager: duel.wager, selections: cSel) : arenaNetProfit(wager: duel.wager, selections: oSel)
                    let rival = uid == duel.challengerId ? duel.opponentName : duel.challengerName
                    BetReminderScheduler.notifyArenaResult(didWin: didWin, points: net, rivalName: rival)
                }
            }
            guard let uid = effectiveUserId else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.refreshDevArenaState(leagueId: leagueId, uid: uid)
            }
            return
        }

        db.collection("leagues").document(leagueId).collection("arenas")
            .whereField("status", isEqualTo: "active")
            .getDocuments { [weak self] snapshot, _ in
                guard let self else { return }
                for doc in snapshot?.documents ?? [] {
                    guard let duel = self.parseArenaDuel(doc: doc) else { continue }
                    let cSel = duel.challengerSelections
                    let oSel = duel.opponentSelections
                    guard !cSel.isEmpty, !oSel.isEmpty else { continue }

                    let cResults = cSel.map { _ in Bool.random() }
                    let oResults = oSel.map { _ in Bool.random() }
                    let cCorrect = cResults.filter { $0 }.count
                    let oCorrect = oResults.filter { $0 }.count
                    let cOdds = self.arenaCombinedOdds(cSel)
                    let oOdds = self.arenaCombinedOdds(oSel)
                    let cPayout = self.arenaPayout(wager: duel.wager, selections: cSel)
                    let oPayout = self.arenaPayout(wager: duel.wager, selections: oSel)
                    let cWin: Bool
                    let oWin: Bool

                    var winnerId: String?
                    var loserId:  String?
                    if cCorrect == cSel.count, oCorrect == oSel.count, cSel.count == oSel.count {
                        cWin = true
                        oWin = true
                        winnerId = "both"
                    } else if cCorrect > oCorrect {
                        cWin = true
                        oWin = false
                        winnerId = duel.challengerId; loserId = duel.opponentId
                    } else if oCorrect > cCorrect {
                        cWin = false
                        oWin = true
                        winnerId = duel.opponentId;   loserId = duel.challengerId
                    } else if cOdds > oOdds {
                        cWin = true
                        oWin = false
                        winnerId = duel.challengerId; loserId = duel.opponentId
                    } else if oOdds > cOdds {
                        cWin = false
                        oWin = true
                        winnerId = duel.opponentId;   loserId = duel.challengerId
                    } else {
                        cWin = false
                        oWin = false
                    }

                    var update: [String: Any] = ["status": "resolved", "resolvedAt": FieldValue.serverTimestamp()]
                    if let wId = winnerId {
                        update["winnerId"] = wId
                    }
                    if let lId = loserId {
                        update["loserId"]  = lId
                    }
                    if cWin {
                        self.adjustPoints(leagueId: leagueId, delta: cPayout, forUserId: duel.challengerId, displayName: duel.challengerName)
                    }
                    if oWin {
                        self.adjustPoints(leagueId: leagueId, delta: oPayout, forUserId: duel.opponentId, displayName: duel.opponentName)
                    }
                    self.recordArenaResultTicket(duel: duel, userId: duel.challengerId, rivalName: duel.opponentName, selections: cSel, didWin: cWin)
                    self.recordArenaResultTicket(duel: duel, userId: duel.opponentId, rivalName: duel.challengerName, selections: oSel, didWin: oWin)
                    if let uid = self.effectiveUserId, uid == duel.challengerId || uid == duel.opponentId {
                        let didWin = uid == duel.challengerId ? cWin : oWin
                        let net = uid == duel.challengerId ? self.arenaNetProfit(wager: duel.wager, selections: cSel) : self.arenaNetProfit(wager: duel.wager, selections: oSel)
                        let rival = uid == duel.challengerId ? duel.opponentName : duel.challengerName
                        BetReminderScheduler.notifyArenaResult(didWin: didWin, points: net, rivalName: rival)
                    }
                    doc.reference.updateData(update)
                }
            }
    }

    // MARK: Serialise helpers

    private func arenaMatchToDict(_ match: ArenaMatch) -> [String: Any] {
        [
            "id":        match.id,
            "home":      match.home,
            "away":      match.away,
            "league":    match.league,
            "startDate": match.startDate ?? NSNull(),
            "odds":      match.odds.map { ["label": $0.label, "value": $0.value] }
        ]
    }

    private func arenaSelectionToDict(_ sel: ArenaBetSelection) -> [String: Any] {
        ["matchId": sel.matchId, "home": sel.home, "away": sel.away,
         "oddLabel": sel.oddLabel, "oddValue": sel.oddValue]
    }

    // MARK: Parse helpers

    func parseArenaDuel(doc: DocumentSnapshot) -> ArenaDuel? {
        let data = doc.data() ?? [:]
        return ArenaDuel(
            id:                    doc.documentID,
            leagueId:              data["leagueId"]              as? String ?? "",
            challengerId:          data["challengerId"]          as? String ?? "",
            challengerName:        data["challengerName"]        as? String ?? "Challenger",
            opponentId:            data["opponentId"]            as? String ?? "",
            opponentName:          data["opponentName"]          as? String ?? "Opponent",
            wager:                 data["wager"]                 as? Int    ?? 20,
            status:                data["status"]                as? String ?? "pending",
            createdAt:             (data["createdAt"]            as? Timestamp)?.dateValue(),
            matches:               (data["matches"]              as? [[String: Any]] ?? []).compactMap { parseArenaMatch($0) },
            challengerSelections:  parseArenaSelections(data["challengerSelections"]),
            opponentSelections:    parseArenaSelections(data["opponentSelections"]),
            winnerId:              data["winnerId"]              as? String,
            loserId:               data["loserId"]              as? String
        )
    }

    private func parseArenaMatch(_ data: [String: Any]) -> ArenaMatch? {
        let odds = (data["odds"] as? [[String: Any]] ?? []).compactMap { dict -> Odd? in
            guard let label = dict["label"] as? String, let value = dict["value"] as? Double else { return nil }
            return Odd(label: label, value: value)
        }
        let startDate: Date? = (data["startDate"] as? Timestamp)?.dateValue()
        return ArenaMatch(
            id:        data["id"]     as? String ?? UUID().uuidString,
            home:      data["home"]   as? String ?? "",
            away:      data["away"]   as? String ?? "",
            league:    data["league"] as? String ?? "",
            startDate: startDate,
            odds:      odds
        )
    }

    private func parseArenaSelections(_ value: Any?) -> [ArenaBetSelection] {
        if let array = value as? [[String: Any]] { return array.compactMap { parseArenaSelectionItem($0) } }
        if let dict  = value as? [String: Any],  let item = parseArenaSelectionItem(dict) { return [item] }
        return []
    }

    private func parseArenaSelectionItem(_ data: [String: Any]) -> ArenaBetSelection? {
        guard let matchId   = data["matchId"]  as? String,
              let oddLabel  = data["oddLabel"] as? String,
              let oddValue  = data["oddValue"] as? Double else { return nil }
        return ArenaBetSelection(
            matchId:  matchId,
            home:     data["home"] as? String ?? "",
            away:     data["away"] as? String ?? "",
            oddLabel: oddLabel,
            oddValue: oddValue
        )
    }

    private func recordArenaResultTicket(
        duel: ArenaDuel,
        userId: String,
        rivalName: String,
        selections: [ArenaBetSelection],
        didWin: Bool
    ) {
        guard !selections.isEmpty else { return }
        let key = "\(userId)|\(duel.leagueId)"
        let defaultsKey = "betsyTicketHistoryDataV2"
        let data = UserDefaults.standard.data(forKey: defaultsKey) ?? Data()
        var history = TicketStore.loadHistory(from: data)
        let externalId = "arena:\(duel.id):\(userId)"
        let alreadyExists = history[key]?.contains { $0.externalId == externalId } ?? false
        guard !alreadyExists else { return }

        let betSelections = selections.map {
            BetSelection(
                matchId: UUID(),
                eventId: $0.matchId,
                sportKey: nil,
                home: $0.home,
                away: $0.away,
                league: "Arena",
                startDate: duel.createdAt,
                oddLabel: $0.oddLabel,
                oddValue: $0.oddValue,
                addedAt: duel.createdAt
            )
        }
        let payout = arenaPayout(wager: duel.wager, selections: selections)
        let ticket = UserTicket(
            date: DevSimulationClock.now(),
            selections: betSelections,
            stake: duel.wager,
            potentialPayout: payout,
            potentialNetProfit: arenaNetProfit(wager: duel.wager, selections: selections),
            isResultKnown: true,
            wasWon: didWin,
            source: "arena",
            contextTitle: "Reto vs \(rivalName)",
            externalId: externalId
        )
        var scoped = history[key] ?? []
        scoped.insert(ticket, at: 0)
        history[key] = scoped
        UserDefaults.standard.set(TicketStore.saveHistory(history), forKey: defaultsKey)
    }
}
