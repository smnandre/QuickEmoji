import Foundation

struct PickerEntry: Identifiable, Sendable {
    let id: String
    let character: String
    let name: String
    let shortcode: String
    let keywords: [String]
    let category: String
}

@MainActor
final class EmojiSearch {
    static let shared = EmojiSearch()

    typealias RankedCharactersProvider = @MainActor @Sendable (_ bundleID: String, _ limit: Int) -> [String]
    typealias RecentCharactersProvider = @MainActor @Sendable (_ limit: Int) -> [String]
    typealias LanguageCodeProvider = @MainActor @Sendable () -> String

    static let menuBarDefaults: [String] = ["😀", "😂", "❤️", "👍", "🎉", "🔥", "✨", "🙏", "😎", "🥰", "😊", "🤔"]

    private let entries: [PickerEntry]
    private let searchableEntries: [SearchableEntry]
    private let entriesByCharacter: [String: PickerEntry]
    private let shortcodePrefixIndex: [String: [Int]]
    private let rankedCharactersProvider: RankedCharactersProvider
    private let recentCharactersProvider: RecentCharactersProvider

    private convenience init() {
        self.init(languageCodeProvider: {
            Self.emojiLocaleCode(
                from: Locale.preferredLanguages.first ?? Locale.current.identifier
            )
        })
    }

    convenience init(
        languageCodeProvider: @escaping LanguageCodeProvider,
        rankedCharactersProvider: @escaping RankedCharactersProvider = { bundleID, limit in
            UsageTracker.shared.rankedCharacters(for: bundleID, limit: limit)
        },
        recentCharactersProvider: @escaping RecentCharactersProvider = { limit in
            UsageTracker.shared.recentCharacters(limit: limit)
        }
    ) {
        let languageCode = languageCodeProvider()
        self.init(
            entries: Self.specialCharacters(languageCode: languageCode)
                + Self.unicodeEmojis(languageCode: languageCode),
            rankedCharactersProvider: rankedCharactersProvider,
            recentCharactersProvider: recentCharactersProvider
        )
    }

    init(
        entries: [PickerEntry],
        rankedCharactersProvider: @escaping RankedCharactersProvider = { bundleID, limit in
            UsageTracker.shared.rankedCharacters(for: bundleID, limit: limit)
        },
        recentCharactersProvider: @escaping RecentCharactersProvider = { limit in
            UsageTracker.shared.recentCharacters(limit: limit)
        }
    ) {
        var all: [PickerEntry] = []
        all.append(contentsOf: entries)
        self.entries = all
        self.searchableEntries = all.enumerated().map(SearchableEntry.init)
        self.entriesByCharacter = Dictionary(uniqueKeysWithValues: all.map { ($0.character, $0) })
        self.rankedCharactersProvider = rankedCharactersProvider
        self.recentCharactersProvider = recentCharactersProvider

        var prefixIndex: [String: [Int]] = [:]
        for (index, entry) in searchableEntries.enumerated() {
            for prefix in entry.shortcodePrefixes {
                prefixIndex[prefix, default: []].append(index)
            }
        }
        self.shortcodePrefixIndex = prefixIndex
    }

    func search(_ query: String, limit: Int = 50, bundleID: String = "") -> [PickerEntry] {
        let q = Self.normalizeQuery(query)
        guard !q.isEmpty else {
            return deduplicatedDefaults(bundleID: bundleID)
        }

        var results: [PickerEntry] = []
        var partialMatches: [PickerEntry] = []
        var seenIDs = Set<String>()

        if let prefixMatches = shortcodePrefixIndex[q] {
            for index in prefixMatches {
                let entry = searchableEntries[index].entry
                if seenIDs.insert(entry.id).inserted {
                    results.append(entry)
                    if results.count == limit {
                        return results
                    }
                }
            }
        }

        for searchableEntry in searchableEntries {
            let entry = searchableEntry.entry
            guard !seenIDs.contains(entry.id) else { continue }
            guard searchableEntry.matches(query: q) else { continue }
            seenIDs.insert(entry.id)
            if searchableEntry.hasExactMatch(query: q) {
                results.append(entry)
                if results.count == limit {
                    return results
                }
            } else {
                partialMatches.append(entry)
            }
        }

        return Array((results + partialMatches).prefix(limit))
    }

    func defaultEntries(bundleID: String = "") -> [PickerEntry] {
        deduplicatedDefaults(bundleID: bundleID)
    }

    func entries(in categories: Set<String>, limit: Int = 50, bundleID: String = "") -> [PickerEntry] {
        guard !categories.isEmpty else {
            return Array(deduplicatedDefaults(bundleID: bundleID).prefix(limit))
        }

        let ranked = Array(
            rankedEntries(bundleID: bundleID)
                .filter { categories.contains($0.category) }
                .prefix(limit))
        var seenIDs = Set(ranked.map(\.id))
        let rest = entries.lazy
            .filter { categories.contains($0.category) && !seenIDs.contains($0.id) }
            .prefix(max(0, limit - ranked.count))

        return ranked
            + rest.map { entry in
                seenIDs.insert(entry.id)
                return entry
            }
    }

    func recentEntries(bundleID: String = "", limit: Int = 50) -> [PickerEntry] {
        Array(rankedEntries(bundleID: bundleID).prefix(limit))
    }

    func entry(forCharacter character: String) -> PickerEntry? {
        entriesByCharacter[character]
    }

    func menuBarRecentEntries(limit: Int = 12) -> [PickerEntry] {
        var seen = Set<String>()
        var result: [PickerEntry] = []

        for character in recentCharactersProvider(limit) {
            guard result.count < limit else { break }
            guard seen.insert(character).inserted else { continue }
            if let entry = entriesByCharacter[character] {
                result.append(entry)
            }
        }

        for character in Self.menuBarDefaults {
            guard result.count < limit else { break }
            guard seen.insert(character).inserted else { continue }
            if let entry = entriesByCharacter[character] {
                result.append(entry)
            }
        }

        return result
    }

    private func deduplicatedDefaults(bundleID: String) -> [PickerEntry] {
        let ranked = rankedEntries(bundleID: bundleID)
        let rankedIDs = Set(ranked.map(\.id))
        let rest = entries.prefix(20).filter { !rankedIDs.contains($0.id) }
        return ranked + rest
    }

    private func rankedEntries(bundleID: String) -> [PickerEntry] {
        let characters = rankedCharactersProvider(bundleID, 30)
        var seenCharacters = Set<String>()
        return characters.compactMap { char in
            guard seenCharacters.insert(char).inserted else { return nil }
            return entriesByCharacter[char]
        }
    }

    func recordUsage(_ entry: PickerEntry, bundleID: String = "") {
        UsageTracker.shared.recordUsage(entry.character, bundleID: bundleID)
    }

    nonisolated private static func normalize(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func normalizeQuery(_ string: String) -> String {
        var query = normalize(string)
        guard query.count > 1, query.first == ":" else { return query }
        query.removeFirst()
        if query.last == ":" {
            query.removeLast()
        }
        return query
    }

    nonisolated static func primaryLanguageCode(from localeIdentifier: String) -> String {
        localeIdentifier
            .split { $0 == "_" || $0 == "-" }
            .first
            .map { String($0).lowercased() } ?? ""
    }

    nonisolated static func emojiLocaleCode(from localeIdentifier: String) -> String {
        let components = localeIdentifier.split { $0 == "_" || $0 == "-" }
        guard let language = components.first.map({ String($0).lowercased() }) else { return "" }
        if language == "zh", !components.contains(where: { $0.lowercased() == "hant" }) {
            return "zh-Hans"
        }
        return language
    }

    private struct SearchableEntry {
        let entry: PickerEntry
        let normalizedShortcode: String
        let normalizedName: String
        let normalizedCategory: String
        let normalizedKeywords: [String]
        let shortcodePrefixes: [String]

        init(indexedEntry: (offset: Int, element: PickerEntry)) {
            let entry = indexedEntry.element
            self.entry = entry
            self.normalizedShortcode = EmojiSearch.normalize(entry.shortcode)
            self.normalizedName = EmojiSearch.normalize(entry.name)
            self.normalizedCategory = EmojiSearch.normalize(entry.category)
            self.normalizedKeywords = entry.keywords.map(EmojiSearch.normalize)

            var prefixes: [String] = []
            prefixes.reserveCapacity(normalizedShortcode.count)
            for characterIndex in normalizedShortcode.indices {
                let nextIndex = normalizedShortcode.index(after: characterIndex)
                prefixes.append(String(normalizedShortcode[..<nextIndex]))
            }
            self.shortcodePrefixes = prefixes
        }

        func matches(query: String) -> Bool {
            entry.character.contains(query)
                || normalizedShortcode.contains(query)
                || normalizedName.contains(query)
                || normalizedCategory.contains(query)
                || normalizedKeywords.contains(where: { $0.contains(query) })
        }

        func hasExactMatch(query: String) -> Bool {
            normalizedShortcode == query
                || normalizedName == query
                || normalizedCategory == query
                || normalizedKeywords.contains(query)
        }
    }

    private static func specialCharacters(languageCode: String) -> [PickerEntry] {
        let data: [(String, String, String, [String], String)] = [
            ("\u{2190}", "left arrow", "arrow_left", ["arrow", "back"], "arrows"),
            ("\u{2191}", "up arrow", "arrow_up", ["arrow"], "arrows"),
            ("\u{2192}", "right arrow", "arrow_right", ["arrow", "forward"], "arrows"),
            ("\u{2193}", "down arrow", "arrow_down", ["arrow"], "arrows"),
            ("\u{2194}", "left right arrow", "arrow_lr", ["arrow", "horizontal"], "arrows"),
            ("\u{2195}", "up down arrow", "arrow_ud", ["arrow", "vertical"], "arrows"),
            ("\u{21D2}", "right double arrow", "implies", ["arrow", "implies"], "arrows"),
            ("\u{21D4}", "left right double arrow", "iff", ["arrow", "iff", "equivalent"], "arrows"),
            ("\u{27F6}", "long right arrow", "longarrow", ["arrow", "long", "maps"], "arrows"),

            ("\u{00D7}", "multiplication sign", "times", ["multiply"], "math"),
            ("\u{00F7}", "division sign", "divide", ["dots"], "math"),
            ("\u{00B1}", "plus minus", "plusminus", ["plus", "minus"], "math"),
            ("\u{2260}", "not equal", "neq", ["different", "ne"], "math"),
            ("\u{2264}", "less than or equal", "leq", ["less"], "math"),
            ("\u{2265}", "greater than or equal", "geq", ["greater"], "math"),
            ("\u{221E}", "infinity", "infinity", ["infinite"], "math"),
            ("\u{2248}", "approximately equal", "approx", ["approximately"], "math"),
            ("\u{221A}", "square root", "sqrt", ["root"], "math"),
            ("\u{2211}", "summation", "sum", ["sigma"], "math"),
            ("\u{220F}", "product", "prod", ["multiply"], "math"),
            ("\u{222B}", "integral", "integral", ["calculus"], "math"),
            ("\u{2202}", "partial derivative", "partial", ["derivative"], "math"),
            ("\u{0394}", "delta", "delta", ["change"], "math"),
            ("\u{03C0}", "pi", "pi", ["3.14"], "math"),
            ("\u{2205}", "empty set", "emptyset", ["null"], "math"),
            ("\u{2208}", "element of", "in", ["member"], "math"),
            ("\u{2209}", "not element of", "notin", ["member"], "math"),
            ("\u{2229}", "intersection", "inter", ["cap", "and"], "math"),
            ("\u{222A}", "union", "union", ["cup", "or"], "math"),
            ("\u{2282}", "subset", "subset", ["set"], "math"),
            ("\u{2200}", "for all", "forall", ["all"], "math"),
            ("\u{2203}", "there exists", "exists", ["exists"], "math"),

            ("\u{2014}", "em dash", "emdash", ["long"], "typography"),
            ("\u{2013}", "en dash", "endash", ["dash"], "typography"),
            ("\u{2026}", "ellipsis", "ellipsis", ["dots"], "typography"),
            ("\u{00AB}", "left guillemet", "laquo", ["quote", "french"], "typography"),
            ("\u{00BB}", "right guillemet", "raquo", ["quote", "french"], "typography"),
            ("\u{2018}", "left single quote", "lsquo", ["quote", "apostrophe"], "typography"),
            ("\u{2019}", "right single quote", "rsquo", ["quote", "apostrophe"], "typography"),
            ("\u{201C}", "left double quote", "ldquo", ["quote"], "typography"),
            ("\u{201D}", "right double quote", "rdquo", ["quote"], "typography"),
            ("\u{2022}", "bullet", "bullet", ["dot", "point"], "typography"),
            ("\u{00A0}", "non-breaking space", "nbsp", ["space"], "typography"),
            ("\u{00B7}", "middle dot", "middot", ["interpunct", "dot"], "typography"),
            ("\u{2009}", "thin space", "thinsp", ["space"], "typography"),

            ("\u{20AC}", "euro", "euro", ["eur", "money"], "currency"),
            ("\u{00A3}", "pound", "pound", ["gbp"], "currency"),
            ("\u{00A5}", "yen", "yen", ["yuan", "jpy"], "currency"),
            ("\u{20BF}", "bitcoin", "btc", ["crypto"], "currency"),

            ("\u{00A9}", "copyright", "copyright", ["rights"], "symbols"),
            ("\u{00AE}", "registered", "registered", ["mark"], "symbols"),
            ("\u{2122}", "trademark", "tm", ["trademark"], "symbols"),
            ("\u{00B0}", "degree", "degree", ["temperature"], "symbols"),
            ("\u{00B5}", "micro", "micro", ["mu"], "symbols"),
            ("\u{2713}", "check mark", "check", ["ok", "done"], "symbols"),
            ("\u{2717}", "cross mark", "cross", ["wrong"], "symbols"),
            ("\u{2605}", "black star", "star", ["fav"], "symbols"),
            ("\u{2665}", "heart", "heart", ["love"], "symbols"),

            ("\u{00B9}", "superscript 1", "sup1", ["sup"], "superscript"),
            ("\u{00B2}", "superscript 2", "sup2", ["squared"], "superscript"),
            ("\u{00B3}", "superscript 3", "sup3", ["cubed"], "superscript"),
        ]

        let localizedKeywords = localizedExtraKeywords(languageCode: languageCode)
        return data.enumerated().map { (i, item) in
            PickerEntry(
                id: "sp-\(i)",
                character: item.0,
                name: item.1,
                shortcode: item.2,
                keywords: item.3 + (localizedKeywords[item.0] ?? []),
                category: item.4
            )
        }
    }

    private static func unicodeEmojis(languageCode: String) -> [PickerEntry] {
        let localizedKeywords = localizedExtraKeywords(languageCode: languageCode)
        let localizedNames = EmojiLocalizedNames.names(for: languageCode)
        return EmojiDatabase.entries.enumerated().map { (i, item) in
            let extras = (extraKeywords[item.0] ?? []) + (localizedKeywords[item.0] ?? [])
            let localizedName = localizedNames[emojiLookupKey(item.0)]
            let keywords = [item.1] + item.3 + extras
            return PickerEntry(
                id: "em-\(i)",
                character: item.0,
                name: localizedName ?? item.1,
                shortcode: item.2,
                keywords: keywords,
                category: item.4
            )
        }
    }

    private static func emojiLookupKey(_ character: String) -> String {
        character.unicodeScalars
            .filter { $0.value != 0xFE0F }
            .map(String.init)
            .joined()
    }

    private static func localizedExtraKeywords(languageCode: String) -> [String: [String]] {
        switch languageCode.lowercased() {
        case "fr":
            return frenchExtraKeywords
        default:
            return [:]
        }
    }

    private static let extraKeywords: [String: [String]] = [
        "🔴": ["dot", "round"],
        "🟠": ["dot", "round"],
        "🟡": ["dot", "round"],
        "🟢": ["dot", "round"],
        "🔵": ["dot", "round"],
        "🟣": ["dot", "round"],
        "🟤": ["dot", "round"],
        "⚫": ["dot", "round", "bullet"],
        "⚪": ["dot", "round"],
        "⭕": ["dot", "round"],
        "🔘": ["dot", "round"],
        "⏺️": ["dot", "round"],
    ]

    private static let frenchExtraKeywords: [String: [String]] = [
        "\u{2190}": ["gauche", "fleche gauche", "flèche gauche"],
        "\u{2191}": ["haut", "fleche haut", "flèche haut"],
        "\u{2192}": ["droite", "fleche droite", "flèche droite"],
        "\u{2193}": ["bas", "fleche bas", "flèche bas"],
        "\u{2194}": ["horizontal"],
        "\u{2195}": ["vertical"],
        "\u{21D2}": ["donc", "implique"],
        "\u{21D4}": ["equivalent", "équivalent"],
        "\u{00D7}": ["fois", "multiplication"],
        "\u{00F7}": ["diviser", "division"],
        "\u{2260}": ["different", "différent"],
        "\u{2264}": ["inferieur", "inférieur"],
        "\u{2265}": ["superieur", "supérieur"],
        "\u{221E}": ["infini"],
        "\u{2248}": ["environ", "approximativement"],
        "\u{221A}": ["racine"],
        "\u{2211}": ["somme"],
        "\u{220F}": ["produit"],
        "\u{222B}": ["integrale", "intégrale"],
        "\u{2202}": ["derivee", "dérivée"],
        "\u{2205}": ["vide"],
        "\u{2208}": ["appartient"],
        "\u{2209}": ["nappartient", "n'appartient"],
        "\u{2229}": ["et"],
        "\u{222A}": ["ou"],
        "\u{2282}": ["sous ensemble"],
        "\u{2200}": ["pour tout"],
        "\u{2203}": ["il existe"],
        "\u{2014}": ["tiret", "tiret long"],
        "\u{2013}": ["tiret", "tiret moyen"],
        "\u{2026}": ["points", "suspension"],
        "\u{00AB}": ["guillemet"],
        "\u{00BB}": ["guillemet"],
        "\u{2022}": ["puce", "point"],
        "\u{00A0}": ["espace insecable", "espace insécable"],
        "\u{00B7}": ["point median", "point médian"],
        "\u{2009}": ["espace fine"],
        "\u{00A3}": ["livre"],
        "\u{00A9}": ["droit"],
        "\u{00AE}": ["marque"],
        "\u{00B0}": ["degre", "degré", "temperature", "température"],
        "\u{2713}": ["coche", "valide"],
        "\u{2717}": ["faux", "croix"],
        "\u{2605}": ["etoile", "étoile"],
        "\u{2665}": ["coeur", "cœur", "amour"],
        "\u{00B2}": ["carre", "carré"],
        "\u{00B3}": ["cube"],
        "😀": ["sourire"],
        "😂": ["rire", "mdr"],
        "😊": ["sourire"],
        "❤️": ["coeur", "cœur", "amour"],
        "👍": ["pouce", "oui", "ok"],
        "👎": ["pouce bas", "non"],
        "🐘": ["elephant", "éléphant"],
        "⭐": ["etoile", "étoile"],
        "🔥": ["feu", "flamme"],
        "💡": ["idee", "idée"],
        "⬆️": ["haut", "fleche haut", "flèche haut"],
        "➡️": ["droite", "fleche droite", "flèche droite"],
        "⬇️": ["bas", "fleche bas", "flèche bas"],
        "⬅️": ["gauche", "fleche gauche", "flèche gauche"],
        "✅": ["coche", "valide"],
        "❌": ["croix", "faux"],
    ]
}
