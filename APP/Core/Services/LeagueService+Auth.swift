import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Authentication

extension LeagueService {

    private func normalizeEmailForFirebase(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return trimmed }
        if trimmed.contains("@") { return trimmed }
        return "\(trimmed)@local.app"
    }

    func registerAccount(username: String, email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let cleanName  = username.trimmingCharacters(in: .whitespacesAndNewlines)
                                 .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let cleanEmail = normalizeEmailForFirebase(email)
        let credential = EmailAuthProvider.credential(withEmail: cleanEmail, password: password)

        isLoading = true
        let finish: (AuthDataResult?, Error?) -> Void = { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = self.authMessage(for: error)
                    completion(.failure(error))
                    return
                }
                self.userId       = result?.user.uid ?? Auth.auth().currentUser?.uid
                self.displayName  = cleanName.isEmpty ? self.defaultDisplayName(uid: self.userId ?? "user") : cleanName
                self.profileEmail = cleanEmail
                self.currentDevProfile = .real
                self.devProfileRaw     = DevProfile.real.rawValue
                // Force play tutorial auto-show for newly registered accounts
                UserDefaults.standard.removeObject(forKey: "tutorialSeenForUserIdV1")
                self.reloadForActiveUser()
                completion(.success(()))
            }
        }

        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            currentUser.link(with: credential) { result, error in
                if let error = error as NSError?,
                   AuthErrorCode(rawValue: error.code) == .emailAlreadyInUse {
                    Auth.auth().signIn(withEmail: cleanEmail, password: password, completion: finish)
                } else {
                    finish(result, error)
                }
            }
        } else {
            Auth.auth().createUser(withEmail: cleanEmail, password: password, completion: finish)
        }
    }

    func signInAccount(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let cleanEmail = normalizeEmailForFirebase(email)
        isLoading = true
        Auth.auth().signIn(withEmail: cleanEmail, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = self.authMessage(for: error)
                    completion(.failure(error))
                    return
                }
                self.userId        = result?.user.uid
                self.profileEmail  = cleanEmail
                self.currentDevProfile = .real
                self.devProfileRaw     = DevProfile.real.rawValue
                self.reloadForActiveUser()
                completion(.success(()))
            }
        }
    }

    func sendPasswordReset(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let cleanEmail = normalizeEmailForFirebase(email)
        Auth.auth().sendPasswordReset(withEmail: cleanEmail) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = self?.authMessage(for: error)
                    completion(.failure(error))
                } else {
                    self?.errorMessage = self?.localized(
                        "Te hemos enviado un email para recuperar la contraseña.",
                        "We sent you a password reset email."
                    )
                    completion(.success(()))
                }
            }
        }
    }

    // MARK: Internal auth helpers

    func signInAnonymously() {
        if isDevModeActive {
            userId = "dev_local_real"   // always the same fixed local ID — no Firebase
            loadDeveloperLeaguesForActiveUser()
            return
        }
        if let uid = Auth.auth().currentUser?.uid {
            userId = uid
            ensureUserProfile()
            listenForLeagues()
            return
        }
        isLoading = true
        Auth.auth().signInAnonymously { [weak self] result, error in
            DispatchQueue.main.async { self?.isLoading = false }
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Auth error: \(error.localizedDescription)"
                }
                return
            }
            self?.userId = result?.user.uid
            self?.ensureUserProfile()
            self?.listenForLeagues()
        }
    }

    func reloadForActiveUser() {
        listener?.remove()
        powerUpListener?.remove()
        challengeListener?.remove()
        arenaListener?.remove()
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
        NotificationCenter.default.post(name: .betsyAuthChanged, object: nil)
        ensureUserProfile()
        listenForLeagues()
    }

    func ensureUserProfile() {
        if isDevModeActive { return }
        guard let uid = effectiveUserId else { return }
        let name = effectiveDisplayName
        if currentDevProfile == .real { displayName = name }
        var data: [String: Any] = [
            "name":      name,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if currentDevProfile == .real, !profileEmail.isEmpty {
            data["email"] = profileEmail
        } else if let testerEmail = currentDevProfile.testerEmail {
            data["email"] = testerEmail
            data["isTester"] = true
        }
        db.collection("users").document(uid).setData(data, merge: true)
    }

    func authMessage(for error: Error) -> String {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return localized("No se pudo autenticar: \(error.localizedDescription)",
                             "Could not authenticate: \(error.localizedDescription)")
        }
        switch code {
        case .emailAlreadyInUse:
            return localized("Ese correo ya tiene cuenta. Inicia sesión.", "That email already has an account. Sign in.")
        case .wrongPassword, .invalidCredential:
            return localized("Correo o contraseña incorrectos.", "Incorrect email or password.")
        case .invalidEmail:
            return localized("El correo no es válido.", "The email is not valid.")
        case .weakPassword:
            return localized("La contraseña debe tener al menos 6 caracteres.", "Password must be at least 6 characters.")
        case .networkError:
            return localized("Sin conexión. Inténtalo de nuevo.", "No connection. Try again.")
        case .userNotFound:
            return localized("No existe una cuenta con ese correo.", "No account exists with that email.")
        case .operationNotAllowed:
            return localized(
                "El registro con email está desactivado en Firebase. Activa Authentication > Sign-in method > Email/Password.",
                "Email sign-up is disabled in Firebase. Enable Authentication > Sign-in method > Email/Password."
            )
        default:
            return localized("No se pudo autenticar: \(error.localizedDescription)",
                             "Could not authenticate: \(error.localizedDescription)")
        }
    }

    func defaultDisplayName(uid: String) -> String {
        let deviceName = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return deviceName.isEmpty ? "Jugador \(uid.prefix(4))" : deviceName
    }
}
