import Foundation

public enum L10n {
    public static func string(_ key: String) -> String {
        Bundle.module.localizedString(forKey: key, value: key, table: nil)
    }

    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: string(key),
            locale: Locale.current,
            arguments: arguments
        )
    }

    public static func string(_ key: String, languageCode: String) -> String {
        guard let resourceLanguageCode = Bundle.module.localizations.first(where: {
            $0.compare(languageCode, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }),
              let path = Bundle.module.path(forResource: resourceLanguageCode, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    public static var supportedLanguageCodes: [String] {
        Bundle.module.localizations.sorted()
    }
}
