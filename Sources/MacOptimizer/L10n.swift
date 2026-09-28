import Foundation
import SwiftUI

public enum L10n {
    public enum Table: String {
        case common, dashboard, cleanup, ai, services
    }

    /// The module localization (e.g. "en", "tr") that `string(_:table:)` resolves against, if any.
    public static func currentLanguage() -> String? {
        let preferences = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
            ?? Bundle.main.preferredLocalizations
        return preferences.lazy.compactMap { preference in
            Bundle.module.localizations.first {
                preference.caseInsensitiveCompare($0) == .orderedSame
                    || preference.lowercased().hasPrefix($0.lowercased() + "-")
            }
        }.first
    }

    /// English name of the UI language in use (e.g. "Turkish", "English"), for model instructions.
    public static func currentLanguageEnglishName() -> String {
        let code = currentLanguage() ?? Bundle.module.developmentLocalization ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
    }

    public static func string(_ key: String, table: Table = .common) -> String {
        let language = currentLanguage()
        if let language,
           let path = Bundle.module.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: table.rawValue)
        }
        return Bundle.module.localizedString(forKey: key, value: key, table: table.rawValue)
    }

    public static func string(_ key: String, table: Table = .common, _ arguments: CVarArg...) -> String {
        String(format: string(key, table: table), locale: Locale.current, arguments: arguments)
    }

    static func string(_ key: String, table: Table = .common, language: String) -> String {
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: table.rawValue)
    }
}

public extension Text {
    init(l10n key: String, table: L10n.Table = .common) {
        self.init(verbatim: L10n.string(key, table: table))
    }
}
