// Looks up app text in the bundle and formats timestamps using the user's regional settings.
import Foundation

func localized(_ text: String, _ arguments: CVarArg...) -> String {
    let format = Bundle.main.localizedString(forKey: text, value: text, table: nil)
    return arguments.isEmpty ? format : String(format: format, locale: Locale.current, arguments: arguments)
}

func formatDate(_ date: Date, template: String) -> String {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
}
