import FirebaseAuth
import FirebaseFirestore

// MARK: - Developer tools & account management

private struct DeveloperLeagueRecord: Codable, Equatable {
    var id: String
    var name: String
    var code: String
    var createdBy: String
    var members: [String]
    var settings: LeagueSettings
}

private struct DeveloperTesterStore: Codable, Equatable {
    var createdTesterIds: [String] = []
}

extension LeagueService {

    private var developerLeaguesKey: String { "betsyDeveloperLocalLeaguesV1" }
    private var developerTesterKey: String { "betsyDeveloperLocalTestersV1" }

    func setDeveloperProfile(_ profile: DevProfile) {
        currentDevProfile = profile
        devProfileRaw     = profile.rawValue
        reloadForActiveUser()
    }

    #if DEBUG
    func seedDeveloperTester(_ profile: DevProfile, completion: ((Bool) -> Void)? = nil) {
        guard let uid = profile.devUserId else { completion?(false); return }
        if isDevModeActive {
            var store = loadDeveloperTesterStore()
            if !store.createdTesterIds.contains(uid) {
                store.createdTesterIds.append(uid)
                saveDeveloperTesterStore(store)
            }
            setDeveloperProfile(profile)
            completion?(true)
            return
        }
        db.collection("users").document(uid).setData([
            "name":      profile.displayName,
            "email":     profile.testerEmail ?? "\(profile.rawValue)@betsy.dev",
            "isTester":  true,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = self?.localized(
                        "No se pudo crear tester: \(error.localizedDescription)",
                        "Could not create tester: \(error.localizedDescription)"
                    )
                    completion?(false)
                } else {
                    completion?(true)
                }
            }
        }
    }

    func deleteDeveloperTester(_ profile: DevProfile, completion: ((Bool) -> Void)? = nil) {
        guard let uid = profile.devUserId else { completion?(false); return }
        if isDevModeActive {
            deleteDeveloperTesterLocally(uid: uid)
            if currentDevProfile == profile { setDeveloperProfile(.real) }
            else { loadDeveloperLeaguesForActiveUser() }
            completion?(true)
            return
        }
        deleteFirestoreFootprint(for: uid) { [weak self] success in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.currentDevProfile == profile {
                    self.setDeveloperProfile(.real)
                } else {
                    self.reloadForActiveUser()
                }
                completion?(success)
            }
        }
    }
    #endif

    func isDeveloperTesterCreated(_ profile: DevProfile) -> Bool {
        guard let uid = profile.devUserId else { return true }
        if !isDevModeActive { return true }
        return loadDeveloperTesterStore().createdTesterIds.contains(uid)
    }

    func loadDeveloperLeaguesForActiveUser() {
        guard let uid = effectiveUserId else { return }
        let records = loadDeveloperLeagueRecords()
        let visible = records
            .filter { $0.members.contains(uid) }
            .map { record in
                FriendLeague(
                    id: record.id,
                    name: record.name,
                    code: record.code,
                    createdBy: record.createdBy,
                    members: record.members.count,
                    settings: record.settings
                )
            }
            .sorted { $0.name < $1.name }
        myLeagues = visible
        if !selectedLeagueId.isEmpty, !visible.contains(where: { $0.id == selectedLeagueId }) {
            selectedLeagueId = visible.first?.id ?? ""
        }
        if selectedLeagueId.isEmpty, let first = visible.first {
            selectedLeagueId = first.id
        }
    }

    func createDeveloperLeague(request: LeagueCreateRequest, createdBy uid: String) {
        var records = loadDeveloperLeagueRecords()
        var code = generateCode(length: 6)
        while records.contains(where: { $0.code == code || $0.id == code }) {
            code = generateCode(length: 6)
        }
        let record = DeveloperLeagueRecord(
            id: code,
            name: request.name,
            code: code,
            createdBy: uid,
            members: [uid],
            settings: request.settings
        )
        records.append(record)
        saveDeveloperLeagueRecords(records)
        selectedLeagueId = code
        loadDeveloperLeaguesForActiveUser()
        loadDeveloperMembers(for: FriendLeague(
            id: record.id,
            name: record.name,
            code: record.code,
            createdBy: record.createdBy,
            members: record.members.count,
            settings: record.settings
        ))
    }

    func updateDeveloperLeague(leagueId: String, request: LeagueCreateRequest, completion: ((Bool) -> Void)? = nil) {
        var records = loadDeveloperLeagueRecords()
        guard let index = records.firstIndex(where: { $0.id == leagueId }) else {
            completion?(false); return
        }
        let settings = normalizedSettings(request.settings)
        if let max = settings.maxParticipants, records[index].members.count > max {
            errorMessage = localized(
                "El máximo no puede ser menor que los miembros actuales.",
                "The maximum cannot be lower than current members."
            )
            completion?(false)
            return
        }
        records[index].name     = request.name
        records[index].settings = settings
        saveDeveloperLeagueRecords(records)
        loadDeveloperLeaguesForActiveUser()
        if let league = myLeagues.first(where: { $0.id == leagueId }) {
            loadDeveloperMembers(for: league)
        }
        completion?(true)
    }

    func joinDeveloperLeague(code: String, uid: String) {
        var records = loadDeveloperLeagueRecords()
        guard let index = records.firstIndex(where: { $0.code == code || $0.id == code }) else {
            errorMessage = localized("Código inválido.", "Invalid code.")
            return
        }
        if !records[index].members.contains(uid) {
            if let max = records[index].settings.maxParticipants,
               records[index].members.count >= max {
                errorMessage = localized("La liga ya está llena.", "The league is full.")
                return
            }
            records[index].members.append(uid)
            saveDeveloperLeagueRecords(records)
        }
        selectedLeagueId = records[index].id
        loadDeveloperLeaguesForActiveUser()
    }

    func leaveDeveloperLeague(leagueId: String, uid: String) {
        var records = loadDeveloperLeagueRecords()
        guard let index = records.firstIndex(where: { $0.id == leagueId }) else { return }
        records[index].members.removeAll(where: { $0 == uid })
        let remaining = records[index].members
        if remaining.isEmpty {
            // Last member — delete the league entirely
            records.remove(at: index)
            DevDataStore.shared.removeLeague(leagueId: leagueId)
        } else {
            // Remaining members exist — clean up this user's data
            DevDataStore.shared.removeMember(leagueId: leagueId, userId: uid)
            DevDataStore.shared.clearArenas(leagueId: leagueId)
            // Transfer admin to earliest remaining member if the admin is leaving
            if records[index].createdBy == uid {
                records[index].createdBy = remaining[0]
            }
        }
        saveDeveloperLeagueRecords(records)
        loadDeveloperLeaguesForActiveUser()
    }

    func loadDeveloperMembers(for league: FriendLeague) {
        membersLoadingId = league.id
        let records = loadDeveloperLeagueRecords()
        guard let record = records.first(where: { $0.id == league.id }) else {
            membersByLeague[league.id] = []
            membersLoadingId = nil
            return
        }
        let store = DevDataStore.shared
        let today = todayKey()
        let members: [LeagueMember] = record.members.map { uid in
            let mp = store.initializeMember(
                leagueId: league.id,
                userId: uid,
                initialPoints: record.settings.initialBalance
            )
            return LeagueMember(
                id: uid,
                name: developerDisplayName(for: uid),
                points: mp.points,
                pointsToday: mp.pointsTodayDate == today ? mp.pointsToday : 0,
                pointsTodayDate: mp.pointsTodayDate,
                recoveryBoostDate: mp.recoveryBoostDate
            )
        }
        membersByLeague[league.id] = members.sorted { $0.points > $1.points }
        membersLoadingId = nil
    }

    // MARK: Dev helpers (called from other service files)

    /// Refreshes the in-memory arena state from DevDataStore — no Firestore involved.
    /// Only exposes duels where `uid` is challenger or opponent (same as the Firestore listener).
    func refreshDevArenaState(leagueId: String, uid: String) {
        let allDuels = DevDataStore.shared.arenas(leagueId: leagueId)
        // Each user sees only their own duels, mirroring the Firestore per-user listener.
        let items    = allDuels.filter { $0.challengerId == uid || $0.opponentId == uid }
        let pending  = items.first { $0.status == "pending"  && $0.opponentId   == uid }
        let outgoing = items.first { $0.status == "pending"  && $0.challengerId  == uid }
        let declined = items.first { $0.status == "declined" && $0.challengerId  == uid }
        let active   = items.first { $0.status == "active"   && ($0.challengerId == uid || $0.opponentId == uid) }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.arenasByLeague[leagueId] = items
            self.pendingArenaInvite  = pending
            self.outgoingArenaInvite = outgoing
            self.declinedArenaInvite = declined
            self.activeArena         = active
        }
    }

    /// Ensures the opponent exists in the local dev league and DevDataStore.
    func ensureOpponentInDevLeague(leagueId: String, opponentId: String, opponentName: String) {
        guard !opponentId.isEmpty else { return }
        var records = loadDeveloperLeagueRecords()
        guard let index = records.firstIndex(where: { $0.id == leagueId }) else { return }
        let initialBalance = records[index].settings.initialBalance
        if !records[index].members.contains(opponentId) {
            records[index].members.append(opponentId)
            saveDeveloperLeagueRecords(records)
            loadDeveloperLeaguesForActiveUser()
        }
        DevDataStore.shared.initializeMember(
            leagueId: leagueId, userId: opponentId, initialPoints: initialBalance
        )
    }

    // MARK: Dev session bootstrap (no Firebase, no login)

    /// Activates a fully local dev session: fixed user ID, auto-seeds the default
    /// dev league + all 4 testers on first use, then loads everything from UserDefaults.
    func bootstrapDevSession() {
        // Drop all Firestore listeners — nothing goes to Firebase in dev mode
        listener?.remove()
        powerUpListener?.remove()
        challengeListener?.remove()
        arenaListener?.remove()
        listener         = nil
        powerUpListener  = nil
        challengeListener = nil
        arenaListener    = nil

        // Fixed stable local identity — same every time
        userId            = "dev_local_real"
        currentDevProfile = .real
        devProfileRaw     = DevProfile.real.rawValue

        // Clear published state
        myLeagues           = []
        membersByLeague     = [:]
        myPowerUpsByLeague  = [:]
        challengesByLeague  = [:]
        activeChallenge     = nil
        pendingArenaInvite  = nil
        outgoingArenaInvite = nil
        declinedArenaInvite = nil
        activeArena         = nil
        arenasByLeague      = [:]
        errorMessage        = nil

        // First-run: create the default dev league with all testers pre-joined
        seedDefaultDevLeagueIfNeeded()

        // Populate published state from local storage
        loadDeveloperLeaguesForActiveUser()
    }

    /// Creates a ready-to-use "Dev League" with all 4 testers on the very first
    /// call. Subsequent calls are no-ops (checks for existing membership first).
    private func seedDefaultDevLeagueIfNeeded() {
        let uid     = "dev_local_real"
        var records = loadDeveloperLeagueRecords()

        // Already has at least one league → nothing to do
        guard !records.contains(where: { $0.members.contains(uid) }) else { return }

        // Register all 4 testers in the tester store
        let testerProfiles: [DevProfile] = [.tester1, .tester2, .tester3, .tester4]
        let testerIds = testerProfiles.compactMap(\.devUserId)
        var testerStore = loadDeveloperTesterStore()
        for tid in testerIds where !testerStore.createdTesterIds.contains(tid) {
            testerStore.createdTesterIds.append(tid)
        }
        saveDeveloperTesterStore(testerStore)

        // Default league settings
        let settings = LeagueSettings(
            visibility:                 .privateLeague,
            maxParticipants:            8,
            allowedCompetitions:        LeagueCompetition.allCases,
            betWindowPreset:            .daily,
            activeWeekdays:             [],
            challengesOutsideBetWindow: true,
            initialBalance:             1000,
            betsPerActiveDay:           3
        )

        let members = [uid] + testerIds
        let code    = "DEVLG1"
        let record  = DeveloperLeagueRecord(
            id:        code,
            name:      "Dev League",
            code:      code,
            createdBy: uid,
            members:   members,
            settings:  settings
        )
        records.append(record)
        saveDeveloperLeagueRecords(records)
        selectedLeagueId = code

        // Initialise every member's balance in DevDataStore
        let store = DevDataStore.shared
        for memberId in members {
            store.initializeMember(leagueId: code, userId: memberId,
                                   initialPoints: settings.initialBalance)
        }
    }

    func deleteCurrentAccount(completion: @escaping (Bool) -> Void) {
        if let devUid = currentDevProfile.devUserId {
            let deletedProfile = currentDevProfile
            if isDevModeActive {
                deleteDeveloperTesterLocally(uid: devUid)
                currentDevProfile = .real
                devProfileRaw = DevProfile.real.rawValue
                resetSession()
                completion(true)
                return
            }
            isLoading = true
            deleteFirestoreFootprint(for: devUid) { [weak self] success in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    guard success else { completion(false); return }
                    if self.currentDevProfile == deletedProfile {
                        self.currentDevProfile = .real
                        self.devProfileRaw     = DevProfile.real.rawValue
                    }
                    self.resetSession()
                    completion(true)
                }
            }
            return
        }

        guard let authUser = Auth.auth().currentUser, let uid = userId else {
            errorMessage = localized("No hay una cuenta activa para eliminar.", "There is no active account to delete.")
            completion(false)
            return
        }

        isLoading = true
        deleteFirestoreFootprint(for: uid) { [weak self] footprintDeleted in
            guard let self else { return }
            if !footprintDeleted {
                DispatchQueue.main.async { self.isLoading = false; completion(false) }
                return
            }
            authUser.delete { [weak self] error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        let nsError = error as NSError
                        if AuthErrorCode(rawValue: nsError.code) == .requiresRecentLogin {
                            self.errorMessage = self.localized(
                                "Por seguridad, vuelve a iniciar sesión y elimina la cuenta otra vez.",
                                "For security, sign in again and delete the account once more."
                            )
                        } else {
                            self.errorMessage = self.localized(
                                "No se pudo eliminar la cuenta: \(error.localizedDescription)",
                                "Could not delete account: \(error.localizedDescription)"
                            )
                        }
                        completion(false)
                        return
                    }
                    self.displayName      = ""
                    self.profileEmail     = ""
                    self.currentDevProfile = .real
                    self.devProfileRaw    = DevProfile.real.rawValue
                    self.resetSession()
                    completion(true)
                }
            }
        }
    }

    func resetDeveloperData() {
        if isDevModeActive {
            UserDefaults.standard.removeObject(forKey: developerLeaguesKey)
            UserDefaults.standard.removeObject(forKey: developerTesterKey)
            DevDataStore.shared.resetAll()
            currentDevProfile = .real
            devProfileRaw = DevProfile.real.rawValue
            reloadForActiveUser()
            return
        }
        let devIds = [DevProfile.tester1.devUserId, DevProfile.tester2.devUserId,
                      DevProfile.tester3.devUserId, DevProfile.tester4.devUserId].compactMap { $0 }
        devIds.forEach { db.collection("users").document($0).delete() }

        db.collection("leagues").getDocuments { [weak self] snapshot, _ in
            guard let self else { return }
            for doc in snapshot?.documents ?? [] {
                let data      = doc.data()
                let createdBy = data["createdBy"] as? String ?? ""
                let members   = data["members"]   as? [String] ?? []
                let hasTester = devIds.contains(createdBy) || members.contains(where: { devIds.contains($0) })
                if hasTester { self.deleteLeagueCompletely(leagueId: doc.documentID); continue }

                devIds.forEach { devId in
                    doc.reference.collection("members").document(devId).delete()
                    let arenasRef = doc.reference.collection("arenas")
                    arenasRef.whereField("challengerId", isEqualTo: devId).getDocuments { snap, _ in snap?.documents.forEach { $0.reference.delete() } }
                    arenasRef.whereField("opponentId",   isEqualTo: devId).getDocuments { snap, _ in snap?.documents.forEach { $0.reference.delete() } }
                    let challengesRef = doc.reference.collection("challenges")
                    challengesRef.whereField("challengerId", isEqualTo: devId).getDocuments { snap, _ in snap?.documents.forEach { $0.reference.delete() } }
                    challengesRef.whereField("opponentId",   isEqualTo: devId).getDocuments { snap, _ in snap?.documents.forEach { $0.reference.delete() } }
                }
            }
        }
    }

    func resetAllLeaguesAndRetos() {
        if isDevModeActive {
            UserDefaults.standard.removeObject(forKey: developerLeaguesKey)
            DevDataStore.shared.resetAll()
            reloadForActiveUser()
            return
        }
        db.collection("leagues").getDocuments { [weak self] snapshot, _ in
            (snapshot?.documents ?? []).forEach { self?.deleteLeagueCompletely(leagueId: $0.documentID) }
        }
    }

    func resetRetos(leagueId: String) {
        if isDevModeActive {
            DevDataStore.shared.clearArenas(leagueId: leagueId)
            pendingArenaInvite  = nil
            outgoingArenaInvite = nil
            declinedArenaInvite = nil
            activeArena         = nil
            activeChallenge     = nil
            arenasByLeague[leagueId]     = []
            challengesByLeague[leagueId] = []
            return
        }
        let ref = db.collection("leagues").document(leagueId)
        ["arenas", "challenges"].forEach { sub in
            ref.collection(sub).getDocuments { snapshot, _ in
                snapshot?.documents.forEach { $0.reference.delete() }
            }
        }
        DispatchQueue.main.async {
            self.arenasByLeague[leagueId]     = []
            self.challengesByLeague[leagueId] = []
            if self.pendingArenaInvite?.leagueId  == leagueId { self.pendingArenaInvite  = nil }
            if self.outgoingArenaInvite?.leagueId == leagueId { self.outgoingArenaInvite = nil }
            if self.declinedArenaInvite?.leagueId == leagueId { self.declinedArenaInvite = nil }
            if self.activeArena?.leagueId         == leagueId { self.activeArena         = nil }
            if self.activeChallenge?.leagueId     == leagueId { self.activeChallenge     = nil }
        }
    }

    func resetAllRetos() {
        db.collection("leagues").getDocuments { [weak self] snapshot, _ in
            (snapshot?.documents ?? []).forEach { self?.resetRetos(leagueId: $0.documentID) }
        }
    }

    func clearArenaDailyLimits() {
        if isDevModeActive {
            DevDataStore.shared.clearAllArenaDailyLimits()
            return
        }
        var ids: [String] = []
        if let realUid = userId { ids.append(realUid) }
        ids.append(contentsOf: [DevProfile.tester1.devUserId, DevProfile.tester2.devUserId,
                                 DevProfile.tester3.devUserId, DevProfile.tester4.devUserId].compactMap { $0 })
        for uid in Set(ids) {
            db.collection("users").document(uid).setData(["arenaChallengeDay": ""], merge: true)
        }
    }

    // MARK: Private helpers

    func deleteLeagueCompletely(leagueId: String) {
        let leagueRef = db.collection("leagues").document(leagueId)
        ["members", "arenas", "challenges"].forEach { sub in
            leagueRef.collection(sub).getDocuments { snapshot, _ in
                snapshot?.documents.forEach { $0.reference.delete() }
            }
        }
        leagueRef.delete()
    }

    func deleteFirestoreFootprint(for uid: String, completion: ((Bool) -> Void)? = nil) {
        let group = DispatchGroup()
        var didFail = false

        group.enter()
        db.collection("users").document(uid).delete { error in
            if error != nil { didFail = true }
            group.leave()
        }

        group.enter()
        db.collection("leagues").getDocuments { [weak self] snapshot, error in
            guard let self else { didFail = true; group.leave(); return }
            if error != nil { didFail = true; group.leave(); return }

            for doc in snapshot?.documents ?? [] {
                let data      = doc.data()
                let createdBy = data["createdBy"] as? String ?? ""
                let members   = data["members"]   as? [String] ?? []
                let leagueRef = doc.reference

                if createdBy == uid { self.deleteLeagueCompletely(leagueId: doc.documentID); continue }

                if members.contains(uid) {
                    let remaining = members.filter { $0 != uid }
                    if remaining.isEmpty { self.deleteLeagueCompletely(leagueId: doc.documentID); continue }
                    group.enter()
                    leagueRef.updateData(["members": remaining, "membersCount": remaining.count]) { error in
                        if error != nil { didFail = true }
                        group.leave()
                    }
                }

                group.enter()
                leagueRef.collection("members").document(uid).delete { _ in group.leave() }

                self.deleteUserScopedDocuments(in: leagueRef.collection("arenas"),     uid: uid, group: group) { didFail = true }
                self.deleteUserScopedDocuments(in: leagueRef.collection("challenges"), uid: uid, group: group) { didFail = true }
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            if didFail {
                self?.errorMessage = self?.localized(
                    "No se pudo eliminar todo. Revisa la conexión e inténtalo otra vez.",
                    "Could not delete everything. Check your connection and try again."
                )
            }
            completion?(!didFail)
        }
    }

    private func loadDeveloperLeagueRecords() -> [DeveloperLeagueRecord] {
        guard let data = UserDefaults.standard.data(forKey: developerLeaguesKey),
              let records = try? JSONDecoder().decode([DeveloperLeagueRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func saveDeveloperLeagueRecords(_ records: [DeveloperLeagueRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: developerLeaguesKey)
    }

    private func loadDeveloperTesterStore() -> DeveloperTesterStore {
        guard let data = UserDefaults.standard.data(forKey: developerTesterKey),
              let store = try? JSONDecoder().decode(DeveloperTesterStore.self, from: data) else {
            return DeveloperTesterStore()
        }
        return store
    }

    private func saveDeveloperTesterStore(_ store: DeveloperTesterStore) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: developerTesterKey)
    }

    private func deleteDeveloperTesterLocally(uid: String) {
        var testerStore = loadDeveloperTesterStore()
        testerStore.createdTesterIds.removeAll(where: { $0 == uid })
        saveDeveloperTesterStore(testerStore)

        var records = loadDeveloperLeagueRecords()
        records = records.compactMap { record in
            var copy = record
            copy.members.removeAll(where: { $0 == uid })
            if copy.createdBy == uid || copy.members.isEmpty { return nil }
            return copy
        }
        saveDeveloperLeagueRecords(records)
    }

    private func developerDisplayName(for uid: String) -> String {
        if uid == "dev_local_real" || uid == userId {
            return displayName.isEmpty ? localized("Yo", "Me") : displayName
        }
        if let profile = DevProfile.allCases.first(where: { $0.devUserId == uid }) {
            return profile.displayName
        }
        return "Tester"
    }

    private func deleteUserScopedDocuments(
        in collection: CollectionReference,
        uid: String,
        group: DispatchGroup,
        markFailure: @escaping () -> Void
    ) {
        ["challengerId", "opponentId"].forEach { field in
            group.enter()
            collection.whereField(field, isEqualTo: uid).getDocuments { snapshot, error in
                if error != nil { markFailure() }
                snapshot?.documents.forEach { $0.reference.delete() }
                group.leave()
            }
        }
    }
}
