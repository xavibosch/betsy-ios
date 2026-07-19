import FirebaseFirestore

// MARK: - Points, transfers, recovery boost

extension LeagueService {

    // MARK: Date helpers

    func todayKey() -> String {
        if isDevModeActive {
            return DevSimulationClock.todayKey()
        }
        let f = DateFormatter()
        f.calendar  = Calendar.current
        f.locale    = Locale(identifier: "en_US_POSIX")
        f.timeZone  = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    func previousDayKey(from key: String) -> String {
        let f = DateFormatter()
        f.calendar  = Calendar.current
        f.locale    = Locale(identifier: "en_US_POSIX")
        f.timeZone  = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: key),
              let prev  = Calendar.current.date(byAdding: .day, value: -1, to: date)
        else { return key }
        return f.string(from: prev)
    }

    // MARK: Public point mutations

    func transferPoints(leagueId: String, winnerId: String, loserId: String, amount: Int) {
        guard amount > 0 else { return }

        if isDevModeActive {
            let initialBalance = myLeagues.first(where: { $0.id == leagueId })?.settings.initialBalance ?? 1000
            let key = todayKey()
            DevDataStore.shared.adjustPoints(leagueId: leagueId, userId: winnerId, initialBalance: initialBalance, delta: amount,  todayKey: key)
            DevDataStore.shared.adjustPoints(leagueId: leagueId, userId: loserId,  initialBalance: initialBalance, delta: -amount, todayKey: key)
            if let league = myLeagues.first(where: { $0.id == leagueId }) {
                loadDeveloperMembers(for: league)
            }
            return
        }

        let winnerRef = db.collection("leagues").document(leagueId).collection("members").document(winnerId)
        let loserRef  = db.collection("leagues").document(leagueId).collection("members").document(loserId)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let winnerSnap = try transaction.getDocument(winnerRef)
                let loserSnap  = try transaction.getDocument(loserRef)
                let key = self.todayKey()

                let winnerPoints      = winnerSnap.data()?["points"]        as? Int    ?? 0
                let winnerToday       = winnerSnap.data()?["pointsToday"]   as? Int    ?? 0
                let winnerTodayDate   = winnerSnap.data()?["pointsTodayDate"] as? String ?? ""
                let newWinnerToday    = (winnerTodayDate == key) ? (winnerToday + amount) : amount
                transaction.updateData([
                    "points":         winnerPoints + amount,
                    "pointsToday":    newWinnerToday,
                    "pointsTodayDate": key
                ], forDocument: winnerRef)

                let loserPoints     = loserSnap.data()?["points"]          as? Int    ?? 0
                let loserToday      = loserSnap.data()?["pointsToday"]     as? Int    ?? 0
                let loserTodayDate  = loserSnap.data()?["pointsTodayDate"] as? String ?? ""
                let newLoserToday   = (loserTodayDate == key) ? (loserToday - amount) : -amount
                transaction.updateData([
                    "points":         loserPoints - amount,
                    "pointsToday":    newLoserToday,
                    "pointsTodayDate": key
                ], forDocument: loserRef)
                return nil
            } catch let error as NSError { errorPointer?.pointee = error; return nil }
        }) { _, _ in }
    }

    func addPoints(leagueId: String, points: Int) {
        guard points != 0 else { return }
        adjustPoints(leagueId: leagueId, delta: points)
    }

    /// Adjust points for the currently effective user.
    func adjustPoints(leagueId: String, delta: Int) {
        guard let uid = effectiveUserId, !leagueId.isEmpty, delta != 0 else { return }

        if isDevModeActive {
            let initialBalance = myLeagues.first(where: { $0.id == leagueId })?.settings.initialBalance ?? 1000
            DevDataStore.shared.adjustPoints(
                leagueId: leagueId, userId: uid,
                initialBalance: initialBalance, delta: delta, todayKey: todayKey()
            )
            if let league = myLeagues.first(where: { $0.id == leagueId }) {
                loadDeveloperMembers(for: league)
            }
            return
        }

        let ref  = db.collection("leagues").document(leagueId).collection("members").document(uid)
        let name = effectiveDisplayName
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let snap    = try transaction.getDocument(ref)
                let data    = snap.data() ?? [:]
                let key     = self.todayKey()
                let current = data["points"]         as? Int    ?? 0
                let today   = data["pointsToday"]    as? Int    ?? 0
                let date    = data["pointsTodayDate"] as? String ?? ""
                transaction.setData([
                    "name":           name,
                    "points":         current + delta,
                    "pointsToday":    (date == key) ? (today + delta) : delta,
                    "pointsTodayDate": key,
                    "updatedAt":      FieldValue.serverTimestamp()
                ], forDocument: ref, merge: true)
                return nil
            } catch let error as NSError { errorPointer?.pointee = error; return nil }
        }) { _, _ in }
    }

    /// Adjust points for an arbitrary DevProfile (used from dev tools).
    func adjustPoints(leagueId: String, delta: Int, for profile: DevProfile) {
        guard !leagueId.isEmpty, delta != 0 else { return }
        let uid: String
        if let devUid = profile.devUserId { uid = devUid }
        else if let realUid = userId { uid = realUid }
        else { return }

        if isDevModeActive {
            let initialBalance = myLeagues.first(where: { $0.id == leagueId })?.settings.initialBalance ?? 1000
            DevDataStore.shared.adjustPoints(
                leagueId: leagueId, userId: uid,
                initialBalance: initialBalance, delta: delta, todayKey: todayKey()
            )
            if let league = myLeagues.first(where: { $0.id == leagueId }) {
                loadDeveloperMembers(for: league)
            }
            return
        }

        let name: String = (profile == .real)
            ? (displayName.isEmpty ? defaultDisplayName(uid: uid) : displayName)
            : profile.displayName

        let ref = db.collection("leagues").document(leagueId).collection("members").document(uid)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let snap    = try transaction.getDocument(ref)
                let data    = snap.data() ?? [:]
                let key     = self.todayKey()
                let current = data["points"]          as? Int    ?? 0
                let today   = data["pointsToday"]     as? Int    ?? 0
                let date    = data["pointsTodayDate"]  as? String ?? ""
                transaction.setData([
                    "name":            name,
                    "points":          current + delta,
                    "pointsToday":     (date == key) ? (today + delta) : delta,
                    "pointsTodayDate": key,
                    "updatedAt":       FieldValue.serverTimestamp()
                ], forDocument: ref, merge: true)
                return nil
            } catch let error as NSError { errorPointer?.pointee = error; return nil }
        }) { _, _ in }
    }

    // MARK: Member doc bootstrap

    func ensureLeagueMemberDoc(leagueId: String, uid: String) {
        if isDevModeActive {
            let initialBalance = myLeagues.first(where: { $0.id == leagueId })?.settings.initialBalance ?? 1000
            DevDataStore.shared.initializeMember(leagueId: leagueId, userId: uid, initialPoints: initialBalance)
            if let league = myLeagues.first(where: { $0.id == leagueId }) {
                loadDeveloperMembers(for: league)
            }
            return
        }

        let name      = effectiveDisplayName
        let leagueRef = db.collection("leagues").document(leagueId)
        let memberRef = leagueRef.collection("members").document(uid)

        leagueRef.getDocument { [weak self] snapshot, _ in
            let settings = self?.parseLeagueSettings(from: snapshot?.data()?["settings"]) ?? .legacyDefaults
            memberRef.getDocument { memberSnapshot, _ in
                if memberSnapshot?.exists == true {
                    memberRef.setData(["name": name, "updatedAt": FieldValue.serverTimestamp()], merge: true)
                    return
                }
                memberRef.setData([
                    "name":              name,
                    "points":            settings.initialBalance,
                    "pointsToday":       0,
                    "pointsTodayDate":   "",
                    "recoveryBoostDate": "",
                    "dailyPowerUpType":  "",
                    "dailyPowerUpDate":  "",
                    "dailyPowerUpUsed":  false,
                    "updatedAt":         FieldValue.serverTimestamp()
                ], merge: false)
            }
        }
    }

    // MARK: Recovery boost

    func claimRecoveryBoostIfNeeded(
        leagueId: String,
        amount: Int = 10,
        todayKeyOverride: String? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let uid = effectiveUserId, !leagueId.isEmpty else { completion?(false); return }

        if isDevModeActive {
            let key            = todayKeyOverride ?? todayKey()
            let normalizedAmt  = max(amount, 1)
            let initialBalance = myLeagues.first(where: { $0.id == leagueId })?.settings.initialBalance ?? 1000
            let store          = DevDataStore.shared
            var mp = store.memberPoints(leagueId: leagueId, userId: uid)
                ?? DevDataStore.MemberPoints(
                    points: initialBalance, pointsToday: 0, pointsTodayDate: "", recoveryBoostDate: nil
                )

            if mp.points > 0 {
                DispatchQueue.main.async {
                    self.errorMessage = self.localized(
                        "Solo puedes recuperar puntos cuando estás a cero o en negativo.",
                        "You can only recover points when you are at zero or negative."
                    )
                    completion?(false)
                }
                return
            }
            if mp.recoveryBoostDate == key {
                DispatchQueue.main.async {
                    self.errorMessage = self.localized(
                        "Ya has usado tu rescate diario hoy.",
                        "You have already used your daily recovery today."
                    )
                    completion?(false)
                }
                return
            }

            mp.points         += normalizedAmt
            mp.pointsToday     = (mp.pointsTodayDate == key) ? (mp.pointsToday + normalizedAmt) : normalizedAmt
            mp.pointsTodayDate = key
            mp.recoveryBoostDate = key
            store.updateMemberPoints(leagueId: leagueId, userId: uid, points: mp)

            DispatchQueue.main.async {
                if let league = self.myLeagues.first(where: { $0.id == leagueId }) {
                    self.loadDeveloperMembers(for: league)
                }
                completion?(true)
            }
            return
        }

        let memberRef      = db.collection("leagues").document(leagueId).collection("members").document(uid)
        let key            = todayKeyOverride ?? todayKey()
        let normalizedAmt  = max(amount, 1)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let snap         = try transaction.getDocument(memberRef)
                let data         = snap.data() ?? [:]
                let currentPts   = data["points"]            as? Int    ?? 0
                let lastBoost    = data["recoveryBoostDate"] as? String ?? ""

                if currentPts > 0 {
                    errorPointer?.pointee = NSError(
                        domain: "RecoveryBoost", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: self.localized(
                            "Solo puedes recuperar puntos cuando estás a cero o en negativo.",
                            "You can only recover points when you are at zero or negative."
                        )]
                    )
                    return nil
                }
                if lastBoost == key {
                    errorPointer?.pointee = NSError(
                        domain: "RecoveryBoost", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: self.localized(
                            "Ya has usado tu rescate diario hoy.",
                            "You have already used your daily recovery today."
                        )]
                    )
                    return nil
                }

                let today    = data["pointsToday"]     as? Int    ?? 0
                let todayDt  = data["pointsTodayDate"] as? String ?? ""
                let newToday = (todayDt == key) ? (today + normalizedAmt) : normalizedAmt
                transaction.setData([
                    "points":            currentPts + normalizedAmt,
                    "pointsToday":       newToday,
                    "pointsTodayDate":   key,
                    "recoveryBoostDate": key,
                    "updatedAt":         FieldValue.serverTimestamp()
                ], forDocument: memberRef, merge: true)
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

    // MARK: Private overload used by Arena resolution

    func adjustPoints(leagueId: String, delta: Int, forUserId uid: String, displayName: String) {
        guard !leagueId.isEmpty, delta != 0 else { return }

        if isDevModeActive {
            let initialBalance = myLeagues.first(where: { $0.id == leagueId })?.settings.initialBalance ?? 1000
            DevDataStore.shared.adjustPoints(
                leagueId: leagueId, userId: uid,
                initialBalance: initialBalance, delta: delta, todayKey: todayKey()
            )
            if let league = myLeagues.first(where: { $0.id == leagueId }) {
                loadDeveloperMembers(for: league)
            }
            return
        }

        let ref = db.collection("leagues").document(leagueId).collection("members").document(uid)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let snap    = try transaction.getDocument(ref)
                let data    = snap.data() ?? [:]
                let key     = self.todayKey()
                let current = data["points"]          as? Int    ?? 0
                let today   = data["pointsToday"]     as? Int    ?? 0
                let date    = data["pointsTodayDate"]  as? String ?? ""
                transaction.setData([
                    "name":            displayName,
                    "points":          current + delta,
                    "pointsToday":     (date == key) ? (today + delta) : delta,
                    "pointsTodayDate": key,
                    "updatedAt":       FieldValue.serverTimestamp()
                ], forDocument: ref, merge: true)
                return nil
            } catch let error as NSError { errorPointer?.pointee = error; return nil }
        }) { _, _ in }
    }
}
