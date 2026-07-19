import Foundation

func localizedDateString(_ date: Date, format: String, lang: AppLang) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale(identifier: lang == .es ? "es_ES" : "en_US")
    formatter.dateFormat = format
    return formatter.string(from: date)
}
