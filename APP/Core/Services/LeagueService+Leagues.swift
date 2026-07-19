import FirebaseFirestore

// MARK: - League CRUD, join/leave, members

extension LeagueService {

    // MARK: Listener

    func listenForLeagues() {
        guard let uid = effectiveUserId else { return }
        listener?.remove()

        if isDevModeActive {
            loadDeveloperLeaguesForActiveUser()
            return
        }

        // Timeout: if Firestore doesn't respond within 10 s, show a connection error.
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.myLeagues.isEmpty && self.errorMessage == nil {
                self.errorMessage = self.localized(
                    "No se pudo conectar con el servidor. Comprueba tu conexión.",
                    "Could not connect to the server. Check your connection."
                )
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutWork)

        listener = db.collection("leagues")
            .whereField("members", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                timeoutWork.cancel()          // cancel timeout once we get a response
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = self?.localized(
                            "Error de conexión: \(error.localizedDescription)",
                            "Connection error: \(error.localizedDescription)"
                        ) ?? error.localizedDescription
                    }
                    return
                }
                let leagues = snapshot?.documents.compactMap { doc -> FriendLeague? in
                    let data      = doc.data()
                    let name      = data["name"]         as? String ?? self?.localized("Liga", "League") ?? "League"
                    let code      = data["code"]         as? String ?? doc.documentID
                    let createdBy = data["createdBy"]    as? String
                    let members   = data["membersCount"] as? Int ?? (data["members"] as? [String])?.count ?? 0
                    let settings  = self?.parseLeagueSettings(from: data["settings"]) ?? .legacyDefaults
                    return FriendLeague(id: doc.documentID, name: name, code: code,
                                        createdBy: createdBy, members: members, settings: settings)
                } ?? []
                DispatchQueue.main.async {
                    self?.myLeagues = leagues.sorted { $0.name < $1.name }
                }
            }
    }

    // MARK: Invite

    func inviteLink(for code: String) -> URL {
        URL(string: "betsy://invite?code=\(code)")!
    }

    func handleInvite(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "betsy",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else { return }
        joinLeague(code: code)
    }

    // MARK: Create / Update

    func createLeague(request: LeagueCreateRequest) {
        guard let uid = effectiveUserId else { return }
        let trimmed = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        let cleanedRequest = LeagueCreateRequest(name: trimmed, settings: normalizedSettings(request.settings))
        if isDevModeActive {
            createDeveloperLeague(request: cleanedRequest, createdBy: uid)
            return
        }
        createLeagueInternal(request: cleanedRequest, createdBy: uid, retries: 3)
    }

    func updateLeague(leagueId: String, request: LeagueCreateRequest, completion: ((Bool) -> Void)? = nil) {
        guard let uid = effectiveUserId else { completion?(false); return }
        let trimmed = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = self.localized("El nombre de la liga no puede estar vacío.", "The league name cannot be empty.")
                completion?(false)
            }
            return
        }
        if isDevModeActive {
            let cleaned = LeagueCreateRequest(name: trimmed, settings: normalizedSettings(request.settings))
            updateDeveloperLeague(leagueId: leagueId, request: cleaned, completion: completion)
            return
        }

        errorMessage = nil
        let cleanedRequest = LeagueCreateRequest(name: trimmed, settings: normalizedSettings(request.settings))
        let ref = db.collection("leagues").document(leagueId)

        db.runTransaction({ [weak self] transaction, errorPointer -> Any? in
            guard let self else { return nil }
            do {
                let snap    = try transaction.getDocument(ref)
                let data    = snap.data() ?? [:]
                let ownerId = data["createdBy"] as? String
                let members = data["members"]   as? [String] ?? []

                if let ownerId, !ownerId.isEmpty, ownerId != uid {
                    errorPointer?.pointee = NSError(
                        domain: "LeaguePermissions", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: self.localized("Solo el creador puede editar esta liga.", "Only the creator can edit this league.")]
                    )
                    return nil
                }
                if let maxParticipants = cleanedRequest.settings.maxParticipants, members.count > maxParticipants {
                    errorPointer?.pointee = NSError(
                        domain: "LeagueCapacity", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: self.localized("El máximo no puede ser menor que los miembros actuales.", "The maximum cannot be lower than current members.")]
                    )
                    return nil
                }
                transaction.updateData([
                    "name":      cleanedRequest.name,
                    "settings":  self.leagueSettingsData(from: cleanedRequest.settings),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error { self?.errorMessage = error.localizedDescription; completion?(false) }
                else         { completion?(true) }
            }
        }
    }

    func createLeagueInternal(request: LeagueCreateRequest, createdBy uid: String, retries: Int) {
        let code = generateCode(length: 6)
        let doc  = db.collection("leagues").document(code)

        doc.getDocument { [weak self] snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = self?.localized("No se pudo crear la liga: \(error.localizedDescription)", "Could not create league: \(error.localizedDescription)")
                }
                return
            }
            if snapshot?.exists == true {
                if retries > 0 { self?.createLeagueInternal(request: request, createdBy: uid, retries: retries - 1) }
                else { DispatchQueue.main.async { self?.errorMessage = self?.localized("No se pudo generar un código único.", "Could not generate a unique code.") } }
                return
            }

            let data: [String: Any] = [
                "name":         request.name,
                "code":         code,
                "createdBy":    uid,
                "members":      [uid],
                "membersCount": 1,
                "settings":     self?.leagueSettingsData(from: request.settings) ?? [:],
                "createdAt":    FieldValue.serverTimestamp()
            ]
            doc.setData(data) { err in
                if let err = err {
                    DispatchQueue.main.async {
                        self?.errorMessage = self?.localized("No se pudo crear la liga: \(err.localizedDescription)", "Could not create league: \(err.localizedDescription)")
                    }
                    return
                }
                DispatchQueue.main.async { self?.selectedLeagueId = code }
                self?.ensureLeagueMemberDoc(leagueId: code, uid: uid)
            }
        }
    }

    // MARK: Join / Leave

    func joinLeague(code: String) {
        guard let uid = effectiveUserId else { return }
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCode.isEmpty else { return }
        errorMessage = nil

        if isDevModeActive {
            joinDeveloperLeague(code: cleanCode, uid: uid)
            return
        }

        let ref = db.collection("leagues").document(cleanCode)
        ref.getDocument { [weak self] snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = self?.localized("No se pudo unirse: \(error.localizedDescription)", "Could not join: \(error.localizedDescription)")
                }
                return
            }
            guard let snapshot, snapshot.exists else {
                DispatchQueue.main.async { self?.errorMessage = self?.localized("Código inválido.", "Invalid code.") }
                return
            }

            self?.db.runTransaction({ (transaction, errorPointer) -> Any? in
                do {
                    let snap     = try transaction.getDocument(ref)
                    var members  = snap.data()?["members"] as? [String] ?? []
                    let settings = self?.parseLeagueSettings(from: snap.data()?["settings"]) ?? .legacyDefaults
                    if members.contains(uid) { return nil }
                    if let max = settings.maxParticipants, members.count >= max {
                        errorPointer?.pointee = NSError(
                            domain: "LeagueCapacity", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: self?.localized("La liga ya está llena.", "The league is full.") ?? "The league is full."]
                        )
                        return nil
                    }
                    members.append(uid)
                    transaction.updateData(["members": members, "membersCount": members.count], forDocument: ref)
                    return nil
                } catch let error as NSError { errorPointer?.pointee = error; return nil }
            }) { _, err in
                if let err = err {
                    DispatchQueue.main.async {
                        self?.errorMessage = self?.localized("No se pudo unirse: \(err.localizedDescription)", "Could not join: \(err.localizedDescription)")
                    }
                } else {
                    DispatchQueue.main.async { self?.selectedLeagueId = cleanCode }
                    self?.ensureLeagueMemberDoc(leagueId: cleanCode, uid: uid)
                }
            }
        }
    }

    func leaveLeague(leagueId: String) {
        guard let uid = effectiveUserId else { return }
        if isDevModeActive {
            leaveDeveloperLeague(leagueId: leagueId, uid: uid)
            return
        }
        let ref = db.collection("leagues").document(leagueId)

        // Captured outside the transaction to avoid Swift-tuple ObjC-bridging issues
        var adminTransferred = false
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let snap = try transaction.getDocument(ref)
                var members   = snap.data()?["members"] as? [String] ?? []
                let createdBy = snap.data()?["createdBy"] as? String ?? ""
                if !members.contains(uid) { return nil }
                members.removeAll(where: { $0 == uid })
                var update: [String: Any] = ["members": members, "membersCount": members.count]
                // If the leaving user was the admin and there are remaining members,
                // transfer admin to the first remaining member (earliest joiner).
                if createdBy == uid, let newAdmin = members.first {
                    update["createdBy"] = newAdmin
                    adminTransferred = true
                }
                transaction.updateData(update, forDocument: ref)
                return members          // still just [String] — safe ObjC bridge
            } catch let error as NSError { errorPointer?.pointee = error; return nil }
        }) { [weak self] result, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = self?.localized("No se pudo salir: \(error.localizedDescription)", "Could not leave: \(error.localizedDescription)")
                }
                return
            }
            ref.collection("members").document(uid).delete()
            let arenasRef     = ref.collection("arenas")
            let challengesRef = ref.collection("challenges")
            for field in ["challengerId", "opponentId"] {
                arenasRef.whereField(field, isEqualTo: uid).getDocuments     { snap, _ in snap?.documents.forEach { $0.reference.delete() } }
                challengesRef.whereField(field, isEqualTo: uid).getDocuments { snap, _ in snap?.documents.forEach { $0.reference.delete() } }
            }
            if let members = result as? [String], members.isEmpty {
                self?.deleteLeagueCompletely(leagueId: leagueId)
            }
        }
    }

    // MARK: Members

    func loadMembers(for league: FriendLeague) {
        if isDevModeActive {
            loadDeveloperMembers(for: league)
            return
        }
        membersLoadingId = league.id
        db.collection("leagues").document(league.id).collection("members")
            .order(by: "points", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.membersLoadingId = nil
                        self.errorMessage = self.localized(
                            "No se pudo cargar miembros: \(error.localizedDescription)",
                            "Could not load members: \(error.localizedDescription)"
                        )
                    }
                    return
                }
                let members = snapshot?.documents.compactMap { doc -> LeagueMember? in
                    let data = doc.data()
                    return LeagueMember(
                        id:                 doc.documentID,
                        name:               data["name"]              as? String ?? "Usuario \(doc.documentID.prefix(4))",
                        points:             data["points"]            as? Int    ?? 0,
                        pointsToday:        data["pointsToday"]       as? Int    ?? 0,
                        pointsTodayDate:    data["pointsTodayDate"]   as? String ?? "",
                        recoveryBoostDate:  data["recoveryBoostDate"] as? String
                    )
                } ?? []
                DispatchQueue.main.async {
                    self.membersByLeague[league.id] = members
                    self.membersLoadingId = nil
                }
            }
    }
}
