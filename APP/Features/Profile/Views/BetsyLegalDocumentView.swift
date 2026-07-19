import SwiftUI

enum BetsyLegalDocumentKind: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }
}

struct BetsyLegalDocumentView: View {
    let kind: BetsyLegalDocumentKind
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private var title: String {
        switch kind {
        case .privacy:
            return appLang == .es ? "Privacidad" : "Privacy"
        case .terms:
            return appLang == .es ? "Términos" : "Terms"
        }
    }

    private var subtitle: String {
        switch kind {
        case .privacy:
            return appLang == .es ? "Cómo Betsy usa y protege tus datos" : "How Betsy uses and protects your data"
        case .terms:
            return appLang == .es ? "Reglas de uso de Betsy" : "Betsy usage rules"
        }
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appLang == .es ? "legal" : "legal")
                            .font(.jbMono(11, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(DS.fg3)
                        Text(title)
                            .font(.bebas(34))
                            .foregroundStyle(DS.fg)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(DS.fg)
                            .frame(width: 44, height: 44)
                            .background(DS.bg2)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar")
                }
                .padding(.horizontal, DS.screenHPad)
                .padding(.top, 18)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(subtitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.fg2)
                            .lineSpacing(3)

                        ForEach(sections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(DS.fg)
                                Text(section.body)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(DS.fg2)
                                    .lineSpacing(4)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.bg1)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous).stroke(DS.line, lineWidth: 1))
                        }

                        Text(appLang == .es
                             ? "Última actualización: mayo de 2026. Contacto de soporte: soporte@betsy.app"
                             : "Last updated: May 2026. Support contact: support@betsy.app")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.fg3)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, DS.screenHPad)
                    .padding(.bottom, 34)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var sections: [(title: String, body: String)] {
        switch kind {
        case .privacy:
            return privacySections
        case .terms:
            return termsSections
        }
    }

    private var privacySections: [(title: String, body: String)] {
        if appLang == .en {
            return [
                ("What Betsy is", "Betsy is a social sports prediction game using virtual points only. Betsy does not allow real-money betting, withdrawals, deposits, gambling prizes or cash rewards."),
                ("Data we collect", "We store your account email, display name, profile photo if you choose one, leagues you create or join, virtual points, tickets, challenge activity, app language and notification preferences."),
                ("How data is used", "We use this data to keep your account signed in, sync private leagues, show leaderboards, resolve virtual tickets, send optional reminders and keep the app reliable."),
                ("Sports data", "During development Betsy can use simulated sports data. When real sports APIs are added, match and odds data will be used only to power the game experience."),
                ("Photos and notifications", "Profile photos are optional and used only inside Betsy. Notifications are optional and can be disabled in the app or iOS Settings."),
                ("Sharing and selling", "Betsy does not sell personal data. Data may be processed by infrastructure providers such as Firebase to run authentication, database sync and analytics."),
                ("Your choices", "You can sign out, delete your account, change language, disable notifications and choose whether to add a profile photo. Deleting your account removes your login, profile, owned leagues, memberships and challenge activity.")
            ]
        }
        return [
            ("Qué es Betsy", "Betsy es un juego social de predicciones deportivas con puntos virtuales. Betsy no permite apuestas con dinero real, ingresos, retiradas, premios de juego ni recompensas en efectivo."),
            ("Datos que recogemos", "Guardamos tu email de cuenta, nombre visible, foto de perfil si la añades, ligas creadas o unidas, puntos virtuales, tickets, actividad de retos, idioma y preferencias de notificaciones."),
            ("Cómo usamos los datos", "Usamos estos datos para mantener tu sesión, sincronizar ligas privadas, mostrar clasificaciones, resolver tickets virtuales, enviar recordatorios opcionales y mantener la app estable."),
            ("Datos deportivos", "Durante el desarrollo Betsy puede usar datos deportivos simulados. Cuando se añadan APIs reales, los partidos y cuotas se usarán solo para alimentar la experiencia de juego."),
            ("Fotos y notificaciones", "La foto de perfil es opcional y se usa solo dentro de Betsy. Las notificaciones son opcionales y se pueden desactivar en la app o en Ajustes de iOS."),
            ("Compartir y vender datos", "Betsy no vende datos personales. Algunos datos pueden ser procesados por proveedores de infraestructura como Firebase para autenticación, base de datos y analítica."),
            ("Tus opciones", "Puedes cerrar sesión, eliminar tu cuenta, cambiar idioma, desactivar notificaciones y decidir si añades foto. Al eliminar tu cuenta se borra tu acceso, perfil, ligas creadas, membresías y actividad de retos.")
        ]
    }

    private var termsSections: [(title: String, body: String)] {
        if appLang == .en {
            return [
                ("Virtual points only", "Betsy is for entertainment and competition with friends. Points have no monetary value and cannot be bought, sold, withdrawn or exchanged for money."),
                ("Private leagues", "Users can create or join leagues, compete on leaderboards, place virtual tickets and challenge friends in Arena duels."),
                ("Fair play", "Do not abuse bugs, manipulate accounts, harass other users or use Betsy for real-money gambling arrangements outside the app."),
                ("Simulated and real sports data", "Some app modes may use simulated fixtures for development or demo purposes. Betsy will label and handle this clearly in the product experience."),
                ("Account responsibility", "Keep your login details secure. You are responsible for activity from your account and for choosing appropriate league settings."),
                ("Changes", "Betsy may improve rules, scoring, sports data providers and league settings as the product evolves.")
            ]
        }
        return [
            ("Solo puntos virtuales", "Betsy es entretenimiento y competición con amigos. Los puntos no tienen valor monetario y no se pueden comprar, vender, retirar ni cambiar por dinero."),
            ("Ligas privadas", "Los usuarios pueden crear o unirse a ligas, competir en clasificaciones, hacer tickets virtuales y retar amigos en duelos Arena."),
            ("Juego limpio", "No abuses de errores, no manipules cuentas, no acoses a otros usuarios y no uses Betsy para acuerdos de apuestas con dinero real fuera de la app."),
            ("Datos simulados y reales", "Algunos modos pueden usar partidos simulados para desarrollo o demo. Betsy debe indicarlo y gestionarlo claramente en la experiencia."),
            ("Responsabilidad de cuenta", "Mantén seguros tus datos de acceso. Eres responsable de la actividad de tu cuenta y de elegir ajustes adecuados para tus ligas."),
            ("Cambios", "Betsy puede mejorar reglas, puntuación, proveedores deportivos y ajustes de liga conforme evolucione el producto.")
        ]
    }
}
