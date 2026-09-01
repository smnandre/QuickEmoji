import Foundation

enum L10n {
    private static let catalog = Catalog.load()

    static func string(
        _ key: String,
        localeIdentifier: String = Locale.preferredLanguages.first ?? Locale.current.identifier
    ) -> String {
        guard let entry = catalog.strings[key] else { return key }

        for language in languageCandidates(for: localeIdentifier) {
            if let value = entry.localizations[language]?.stringUnit.value, !value.isEmpty {
                return value
            }
        }

        return entry.localizations[catalog.sourceLanguage]?.stringUnit.value ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: .current, arguments: arguments)
    }

    private static func languageCandidates(for localeIdentifier: String) -> [String] {
        let components = localeIdentifier.split(whereSeparator: { $0 == "-" || $0 == "_" })
        guard let language = components.first.map({ String($0).lowercased() }) else { return [] }

        var candidates = [localeIdentifier.replacingOccurrences(of: "_", with: "-")]
        if language == "zh", !components.contains(where: { $0.lowercased() == "hant" }) {
            candidates.append("zh-Hans")
        }
        candidates.append(language)
        return candidates
    }
}

private struct Catalog: Decodable {
    let sourceLanguage: String
    let strings: [String: Entry]

    struct Entry: Decodable {
        let localizations: [String: Localization]
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit
    }

    struct StringUnit: Decodable {
        let value: String
    }

    static func load() -> Self {
        guard
            let url = AppResources.bundle.url(forResource: "Localizable", withExtension: "xcstrings"),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(Self.self, from: data)
        else {
            assertionFailure("Missing or invalid Localizable.xcstrings")
            return Self(sourceLanguage: "en", strings: [:])
        }
        return catalog
    }
}
