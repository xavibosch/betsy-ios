import SwiftUI
import UIKit

// MARK: - Auth stage

private enum AuthStage: Equatable {
    case welcome
    case signUp
    case login
}

// MARK: - Root (Stadium dark · matches Claude Design wireframes 01)

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    var previewOnly: Bool = false
    @EnvironmentObject private var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("selectedLanguage") private var lang: AppLang = .es
    @AppStorage("displayName") private var storedUsername: String = ""
    @AppStorage("profileEmail") private var storedEmail: String = ""
    @AppStorage("devSimulatingOnboarding") private var devSimulatingOnboarding = false

    @State private var stage: AuthStage = .welcome
    @State private var appeared = false
    @State private var isAuthenticating = false
    @State private var authError: String? = nil
    @State private var legalKind: BetsyLegalDocumentKind? = nil

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.047).ignoresSafeArea()

            Group {
                switch stage {
                case .welcome:
                    welcomeScreen
                        .transition(welcomeTransition)
                case .signUp:
                    SignUpFormView(lang: lang,
                                   onBack: { goTo(.welcome) },
                                   onSwitchToLogin: { goTo(.login) },
                                   isLoading: isAuthenticating,
                                   serverError: authError,
                                   onShowLegal: { legalKind = $0 },
                                  onSubmit: { username, email, password in
                                       register(username: username, email: email, password: password)
                                   })
                    .transition(forwardTransition)
                case .login:
                    LoginFormView(lang: lang,
                                  onBack: { goTo(.welcome) },
                                  onSwitchToSignUp: { goTo(.signUp) },
                                  isLoading: isAuthenticating,
                                  serverError: authError,
                                  onResetPassword: { email in
                                      resetPassword(email: email)
                                  },
                                  onSubmit: { email, password in
                                      signIn(email: email, password: password)
                                  })
                    .transition(forwardTransition)
                }
            }

            // Preview close button (only in preview mode)
            if previewOnly {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            hasSeenOnboarding = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .black))
                                Text("Cerrar")
                                    .font(.system(size: 11, weight: .black))
                                    .tracking(0.6)
                            }
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 60)
                    Spacer()
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: stage)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.70, dampingFraction: 0.84).delay(0.06)) {
                    appeared = true
                }
            }
        }
        .sheet(item: $legalKind) { kind in
            BetsyLegalDocumentView(kind: kind)
        }
    }

    private var welcomeTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity,
                removal: .opacity.combined(with: .move(edge: .leading))
            )
    }

    private var forwardTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            )
    }

    private func goTo(_ s: AuthStage) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        authError = nil
        stage = s
    }

    private func finishAuth() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if previewOnly {
            hasSeenOnboarding = true
        } else if reduceMotion {
            hasSeenOnboarding = true
        } else {
            withAnimation(.easeInOut(duration: 0.28)) { hasSeenOnboarding = true }
        }
    }

    private func register(username: String, email: String, password: String) {
        // Dev simulated mode: skip all Firebase, just finish immediately
        if devSimulatingOnboarding {
            devSimulatingOnboarding = false
            finishAuth()
            return
        }
        guard !isAuthenticating else { return }
        authError = nil
        isAuthenticating = true
        let cleanName = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        leagueService.registerAccount(username: cleanName, email: cleanEmail, password: password) { result in
            isAuthenticating = false
            switch result {
            case .success:
                storedUsername = cleanName
                storedEmail = cleanEmail
                finishAuth()
            case .failure:
                authError = leagueService.errorMessage ?? (lang == .es ? "No se pudo crear la cuenta." : "Could not create the account.")
            }
        }
    }

    private func signIn(email: String, password: String) {
        // Dev simulated mode: skip all Firebase, just finish immediately
        if devSimulatingOnboarding {
            devSimulatingOnboarding = false
            finishAuth()
            return
        }
        guard !isAuthenticating else { return }
        authError = nil
        isAuthenticating = true
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        leagueService.signInAccount(email: cleanEmail, password: password) { result in
            isAuthenticating = false
            switch result {
            case .success:
                storedEmail = cleanEmail
                finishAuth()
            case .failure:
                authError = leagueService.errorMessage ?? (lang == .es ? "No se pudo iniciar sesión." : "Could not sign in.")
            }
        }
    }

    private func resetPassword(email: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else {
            authError = lang == .es ? "Escribe tu correo para recuperar la contraseña." : "Enter your email to reset your password."
            return
        }
        leagueService.sendPasswordReset(email: cleanEmail) { result in
            switch result {
            case .success:
                authError = leagueService.errorMessage
            case .failure:
                authError = leagueService.errorMessage ?? (lang == .es ? "No se pudo enviar el email." : "Could not send the email.")
            }
        }
    }

    // MARK: ─── WELCOME (01.2) ────────────────────────────────────────────

    @ViewBuilder
    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            // ── Top bar: BETSY mark + ES/EN toggle ───────────────
            HStack {
                HStack(spacing: 6) {
                    Image("BetsyLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)
                    Text("BETSY")
                        .font(.system(size: 13, weight: .black))
                        .tracking(2.4)
                        .foregroundStyle(Color.white)
                }
                Spacer()

                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    lang = (lang == .es) ? .en : .es
                } label: {
                    HStack(spacing: 4) {
                        Text(lang == .es ? "ES" : "EN")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1.2)
                            .foregroundStyle(Color.white)
                        Image(systemName: "globe")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.09))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(lang == .es ? "Idioma: Español. Cambiar a inglés" : "Language: English. Switch to Spanish")
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer(minLength: 14)

            // ── Hero ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 22) {
                Text(lang == .es ? "COMPITE CON QUIEN QUIERAS" : "COMPETE WITH ANYONE")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2.4)
                    .foregroundStyle(Color.white.opacity(0.55))

                // MASSIVE all-caps headline
                VStack(alignment: .leading, spacing: -4) {
                    Text(lang == .es ? "LA LIGA" : "PROVE YOUR")
                        .font(.system(size: 56, weight: .black))
                        .tracking(-1.5)
                        .foregroundStyle(Color.white)
                    Text(lang == .es ? "LA HACES" : "KNOWLEDGE")
                        .font(.system(size: 56, weight: .black))
                        .tracking(-1.5)
                        .foregroundStyle(Color.white)
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text(lang == .es ? "TÚ" : "& COMPETE")
                            .font(.system(size: 56, weight: .black))
                            .tracking(-1.5)
                            .foregroundStyle(Theme.accent)
                        Text(".")
                            .font(.system(size: 56, weight: .black))
                            .foregroundStyle(Color.white)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)

                Text(lang == .es
                     ? "Crea ligas privadas con tus amigos. Apuesta\npuntos virtuales. Sube en la tabla. Reta\ndirectamente en el Arena."
                     : "Create private leagues with friends. Bet virtual\npoints. Climb the table. Duel directly in the\nArena.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineSpacing(3)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer()

            // ── CTAs (capsule pill buttons) ─────────────────
            VStack(spacing: 12) {
                // Primary — lime pill
                Button {
                    goTo(.signUp)
                } label: {
                    Text(lang == .es ? "Crear cuenta" : "Create account")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                        .shadow(color: Theme.accent.opacity(0.40), radius: 18, x: 0, y: 6)
                }
                .buttonStyle(StadiumPress())

                // Secondary — dark pill
                Button {
                    goTo(.login)
                } label: {
                    Text(lang == .es ? "Iniciar sesión" : "Sign in")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white.opacity(0.09))
                        .overlay(Capsule().stroke(Color.white.opacity(0.32), lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(StadiumPress())

                Text(lang == .es ? "Puntos virtuales. Sin dinero real." : "Virtual points. No real money.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.top, 6)

                legalLinks
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 4) {
            Text(lang == .es ? "Al continuar aceptas" : "By continuing you accept")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.62))
            Button(lang == .es ? "Términos" : "Terms") { legalKind = .terms }
                .font(.system(size: 11, weight: .black))
                .underline()
                .foregroundStyle(Color.white.opacity(0.86))
            Text("·")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.62))
            Button(lang == .es ? "Privacidad" : "Privacy") { legalKind = .privacy }
                .font(.system(size: 11, weight: .black))
                .underline()
                .foregroundStyle(Color.white.opacity(0.86))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: — Sign Up (01.3)
// ─────────────────────────────────────────────────────────────────────────────

private struct SignUpFormView: View {
    let lang: AppLang
    let onBack: () -> Void
    let onSwitchToLogin: () -> Void
    let isLoading: Bool
    let serverError: String?
    let onShowLegal: (BetsyLegalDocumentKind) -> Void
    let onSubmit: (String, String, String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var agreeTerms = false
    @State private var showPassword = false
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            stadiumBackBar(onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // Eyebrow + headline
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang == .es ? "ÚNETE A BETSY" : "JOIN BETSY")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2.4)
                            .foregroundStyle(Color.white.opacity(0.72))

                        VStack(alignment: .leading, spacing: -2) {
                            Text(lang == .es ? "CREAR" : "CREATE")
                                .font(.system(size: 46, weight: .black))
                                .tracking(-1)
                                .foregroundStyle(Color.white)
                            Text(lang == .es ? "CUENTA" : "ACCOUNT")
                                .font(.system(size: 46, weight: .black))
                                .tracking(-1)
                                .foregroundStyle(Color.white)
                        }
                    }
                    .padding(.top, 8)

                    // Fields
                    VStack(alignment: .leading, spacing: 16) {
                        StadiumField(
                            label: lang == .es ? "NOMBRE DE USUARIO" : "USERNAME",
                            placeholder: "@alex.r",
                            text: $username
                        )
                        StadiumField(
                            label: lang == .es ? "CORREO ELECTRÓNICO" : "EMAIL",
                            placeholder: "alex@correo.com",
                            text: $email,
                            keyboard: .emailAddress
                        )
                        StadiumPasswordField(
                            label: lang == .es ? "CONTRASEÑA" : "PASSWORD",
                            text: $password,
                            showText: $showPassword
                        )
                    }

                    // Terms checkbox
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        agreeTerms.toggle()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(agreeTerms ? Theme.accent : Color.white.opacity(0.09))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(agreeTerms ? Theme.accent : Color.white.opacity(0.42), lineWidth: 1.5)
                                    )
                                if agreeTerms {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(Theme.accentInk)
                                }
                            }
                            Text(lang == .es ? "Acepto términos y privacidad" : "I accept terms and privacy")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.78))
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 4) {
                        Button(lang == .es ? "Ver términos" : "View terms") { onShowLegal(.terms) }
                        Text("·").foregroundStyle(Color.white.opacity(0.5))
                        Button(lang == .es ? "Ver privacidad" : "View privacy") { onShowLegal(.privacy) }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)

                    if let error = error ?? serverError {
                        Text(error)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.hot)
                    }

                    // Primary CTA — lime pill with arrow
                    Button { submit() } label: {
                        HStack(spacing: 6) {
                            if isLoading {
                                ProgressView()
                                    .tint(Theme.accentInk)
                            } else {
                                Text(lang == .es ? "Registrarse" : "Sign up")
                                    .font(.system(size: 15, weight: .black))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .black))
                            }
                        }
                        .foregroundStyle(isFormValid ? Theme.accentInk : Color.white.opacity(0.62))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(isFormValid ? Theme.accent : Color.white.opacity(0.11))
                        .clipShape(Capsule())
                        .shadow(color: isFormValid ? Theme.accent.opacity(0.40) : Color.clear, radius: 18, x: 0, y: 6)
                    }
                    .buttonStyle(StadiumPress())
                    .disabled(!isFormValid || isLoading)

                    // Footer link
                    HStack(spacing: 6) {
                        Text(lang == .es ? "¿Ya tienes cuenta?" : "Already have an account?")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.68))
                        Button { onSwitchToLogin() } label: {
                            Text(lang == .es ? "Iniciar sesión" : "Sign in")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }

    private var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 6
            && agreeTerms
    }

    private func submit() {
        guard isFormValid else {
            withAnimation(reduceMotion ? nil : .default) { error = lang == .es ? "Completa todos los campos" : "Fill in all fields" }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        onSubmit(
            username.trimmingCharacters(in: .whitespaces),
            email.trimmingCharacters(in: .whitespacesAndNewlines),
            password
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: — Login (01.4)
// ─────────────────────────────────────────────────────────────────────────────

private struct LoginFormView: View {
    let lang: AppLang
    let onBack: () -> Void
    let onSwitchToSignUp: () -> Void
    let isLoading: Bool
    let serverError: String?
    let onResetPassword: (String) -> Void
    let onSubmit: (String, String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword = false
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            stadiumBackBar(onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // Eyebrow + headline
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang == .es ? "DE VUELTA" : "WELCOME BACK")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2.4)
                            .foregroundStyle(Color.white.opacity(0.55))

                        VStack(alignment: .leading, spacing: -2) {
                            Text(lang == .es ? "INICIAR" : "SIGN")
                                .font(.system(size: 46, weight: .black))
                                .tracking(-1)
                                .foregroundStyle(Color.white)
                            Text(lang == .es ? "SESIÓN" : "IN")
                                .font(.system(size: 46, weight: .black))
                                .tracking(-1)
                                .foregroundStyle(Color.white)
                        }
                    }
                    .padding(.top, 8)

                    // Fields
                    VStack(alignment: .leading, spacing: 16) {
                        StadiumField(
                            label: lang == .es ? "CORREO O USUARIO" : "EMAIL OR USERNAME",
                            placeholder: "alex@correo.com",
                            text: $email,
                            keyboard: .emailAddress
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(lang == .es ? "CONTRASEÑA" : "PASSWORD")
                                    .font(.system(size: 11, weight: .black))
                                    .tracking(1.4)
                                    .foregroundStyle(Color.white.opacity(0.68))
                                Spacer()
                                Button(lang == .es ? "¿OLVIDASTE?" : "FORGOT?") {
                                    onResetPassword(email)
                                }
                                    .font(.system(size: 11, weight: .black))
                                    .tracking(1.0)
                                    .foregroundStyle(Theme.accent)
                            }

                            HStack(spacing: 10) {
                                Group {
                                    if showPassword {
                                        TextField("••••••••••••", text: $password)
                                    } else {
                                        SecureField("••••••••••••", text: $password)
                                    }
                                }
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white)

                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.68))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(showPassword ? (lang == .es ? "Ocultar contraseña" : "Hide password") : (lang == .es ? "Mostrar contraseña" : "Show password"))
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.08))
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                    }

                    if let error = error ?? serverError {
                        Text(error)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.hot)
                    }

                    // Primary CTA
                    Button { submit() } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(Theme.accentInk)
                            } else {
                                Text(lang == .es ? "Entrar" : "Sign in")
                                    .font(.system(size: 15, weight: .black))
                            }
                        }
                        .foregroundStyle(isFormValid ? Theme.accentInk : Color.white.opacity(0.62))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(isFormValid ? Theme.accent : Color.white.opacity(0.11))
                        .clipShape(Capsule())
                        .shadow(color: isFormValid ? Theme.accent.opacity(0.40) : Color.clear, radius: 18, x: 0, y: 6)
                    }
                    .buttonStyle(StadiumPress())
                    .disabled(!isFormValid || isLoading)

                    // Footer link
                    HStack(spacing: 6) {
                        Text(lang == .es ? "¿Nuevo aquí?" : "New here?")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.68))
                        Button { onSwitchToSignUp() } label: {
                            Text(lang == .es ? "Crea una cuenta" : "Create one")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 4
    }

    private func submit() {
        guard isFormValid else {
            withAnimation(reduceMotion ? nil : .default) { error = lang == .es ? "Revisa tus datos" : "Check your credentials" }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        onSubmit(email.trimmingCharacters(in: .whitespacesAndNewlines), password)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: — Shared stadium components
// ─────────────────────────────────────────────────────────────────────────────

@ViewBuilder
private func stadiumBackBar(onBack: @escaping () -> Void) -> some View {
    HStack {
        Button { onBack() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.09))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Volver")
        Spacer()
    }
    .padding(.horizontal, 18)
    .padding(.top, 10)
}

private struct StadiumField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .black))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.72))

            TextField("", text: $text, prompt: Text(placeholder)
                        .foregroundStyle(Color.white.opacity(0.56)))
                .keyboardType(keyboard)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Color.white.opacity(0.08))
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .clipShape(Capsule())
        }
    }
}

private struct StadiumPasswordField: View {
    let label: String
    @Binding var text: String
    @Binding var showText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(Color.white.opacity(0.68))
                Spacer()
                Button { showText.toggle() } label: {
                    Text(showText ? "OCULTAR" : "VER")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.0)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Group {
                    if showText {
                        TextField("••••••••••••", text: $text)
                    } else {
                        SecureField("••••••••••••", text: $text)
                    }
                }
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Color.white.opacity(0.08))
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
            .clipShape(Capsule())
        }
    }
}

private struct StadiumPress: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
