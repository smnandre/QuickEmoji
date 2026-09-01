import XCTest
@testable import QuickEmoji

@MainActor
final class EmojiSearchTests: XCTestCase {
    private let entries = [
        PickerEntry(
            id: "1",
            character: "→",
            name: "Right Arrow",
            shortcode: "arrow_right",
            keywords: ["arrow", "forward", "droite"],
            category: "arrows"
        ),
        PickerEntry(
            id: "2",
            character: "✓",
            name: "Check Mark",
            shortcode: "check_mark",
            keywords: ["ok", "done", "coche"],
            category: "symbols"
        ),
        PickerEntry(
            id: "3",
            character: "π",
            name: "Pi",
            shortcode: "pi",
            keywords: ["math", "circle"],
            category: "math"
        ),
        PickerEntry(
            id: "4",
            character: "🇫🇷",
            name: "Flag: France",
            shortcode: "flag_france",
            keywords: ["country", "flag", "france"],
            category: "flags"
        ),
    ]

    func testShortcodePrefixMatchesFirst() {
        let search = makeSearch()

        let results = search.search("arr", limit: 5)

        XCTAssertEqual(results.first?.character, "→")
    }

    func testColonPrefixedShortcodeQuery() {
        let search = makeSearch()
        let results = search.search(":arr", limit: 10)

        XCTAssertEqual(results.first?.character, "→")
    }

    func testColonWrappedShortcodeQuery() {
        let search = makeSearch()
        let results = search.search(":arr:", limit: 10)

        XCTAssertEqual(results.first?.character, "→")
    }

    func testSearchMatchesNameCaseInsensitively() {
        let search = makeSearch()

        let results = search.search("CHECK", limit: 5)

        XCTAssertEqual(results.map(\.character), ["✓"])
    }

    func testSearchMatchesKeywords() {
        let search = makeSearch()

        let results = search.search("droi", limit: 5)

        XCTAssertEqual(results.map(\.character), ["→"])
    }

    func testCountryFlagMatchesISOCode() {
        let search = makeSearch()

        let results = search.search("fr", limit: 5)

        XCTAssertEqual(results.first?.character, "🇫🇷")
    }

    func testCountryCodeIsDerivedOnlyFromRegionalIndicatorFlags() {
        XCTAssertEqual(EmojiSearch.countryCode(forFlag: "🇫🇷"), "fr")
        XCTAssertNil(EmojiSearch.countryCode(forFlag: "🏳️‍🌈"))
        XCTAssertNil(EmojiSearch.countryCode(forFlag: "fr"))
    }

    func testSearchRespectsLimit() {
        let search = makeSearch()

        let results = search.search("a", limit: 2)

        XCTAssertEqual(results.count, 2)
    }

    func testDotQueryReturnsColloquiallyDottedCharacters() {
        let results = EmojiSearch.shared.search("dot", limit: 100)
        let characters = results.map(\.character)

        for expected in ["•", "·", "🔴", "🟢", "⚫", "⚪", "🔘", "💠"] {
            XCTAssertTrue(
                characters.contains(expected),
                "Expected 'dot' search to include \(expected); got \(characters.count) results: \(characters)"
            )
        }
    }

    func testFrenchAliasesAreEnabledForFrenchLocale() {
        let search = EmojiSearch(languageCodeProvider: { "fr" }, rankedCharactersProvider: { _, _ in [] })

        XCTAssertEqual(search.search("feu", limit: 5).first?.character, "🔥")
        XCTAssertTrue(search.search("éléphant", limit: 10).map(\.character).contains("🐘"))
        XCTAssertTrue(search.search("coche", limit: 10).map(\.character).contains("✓"))
        XCTAssertTrue(search.search("fleche droite", limit: 10).map(\.character).contains("→"))
    }

    func testFrenchUnicodeShortNamesAreDisplayedAndSearchable() {
        let search = EmojiSearch(languageCodeProvider: { "fr" }, rankedCharactersProvider: { _, _ in [] })

        XCTAssertEqual(search.entry(forCharacter: "😀")?.name, "visage rieur")
        XCTAssertTrue(search.search("visage rieur", limit: 10).map(\.character).contains("😀"))
        XCTAssertTrue(search.search("grinning face", limit: 10).map(\.character).contains("😀"))
        XCTAssertGreaterThanOrEqual(EmojiLocalizedNames.names(for: "fr").count, 1700)
    }

    func testFrenchAliasesAreDisabledForEnglishLocale() {
        let search = EmojiSearch(languageCodeProvider: { "en" }, rankedCharactersProvider: { _, _ in [] })

        XCTAssertFalse(search.search("feu", limit: 20).map(\.character).contains("🔥"))
        XCTAssertFalse(search.search("coeur", limit: 20).map(\.character).contains("❤️"))
        XCTAssertFalse(search.search("coche", limit: 20).map(\.character).contains("✓"))
    }

    func testEnglishSearchStillWorksWhenFrenchLocaleIsEnabled() {
        let search = EmojiSearch(languageCodeProvider: { "fr" }, rankedCharactersProvider: { _, _ in [] })

        XCTAssertTrue(search.search("fire", limit: 20).map(\.character).contains("🔥"))
        XCTAssertTrue(search.search("elephant", limit: 10).map(\.character).contains("🐘"))
        XCTAssertTrue(search.search("check", limit: 10).map(\.character).contains("✓"))
    }

    func testPrimaryLanguageCodeExtraction() {
        XCTAssertEqual(EmojiSearch.primaryLanguageCode(from: "fr_FR"), "fr")
        XCTAssertEqual(EmojiSearch.primaryLanguageCode(from: "en-US"), "en")
        XCTAssertEqual(EmojiSearch.primaryLanguageCode(from: ""), "")
        XCTAssertEqual(EmojiSearch.emojiLocaleCode(from: "fr-CA"), "fr")
        XCTAssertEqual(EmojiSearch.emojiLocaleCode(from: "de-DE"), "en")
        XCTAssertEqual(EmojiSearch.emojiLocaleCode(from: "zh-Hans-CN"), "en")
    }

    func testStringsCatalogHasRequestedUITranslations() {
        XCTAssertEqual(L10n.string("Show Picker", localeIdentifier: "fr-FR"), "Afficher le sélecteur")
        XCTAssertEqual(L10n.string("Show Picker", localeIdentifier: "en-US"), "Show Picker")
        XCTAssertEqual(L10n.string("Show Picker", localeIdentifier: "de-DE"), "Show Picker")
    }

    func testDefaultEntriesPrioritizeRankedCharactersWithoutDuplicates() {
        let search = makeSearch(rankedCharactersProvider: { _, _ in ["✓", "→", "✓"] })

        let results = search.defaultEntries(bundleID: "com.example.app")

        XCTAssertEqual(results.prefix(2).map(\.character), ["✓", "→"])
        XCTAssertEqual(Set(results.map(\.id)).count, results.count)
    }

    func testEntryForCharacterResolvesGlyph() {
        let search = makeSearch()

        XCTAssertEqual(search.entry(forCharacter: "→")?.name, "Right Arrow")
        XCTAssertNil(search.entry(forCharacter: "😀"))
    }

    func testMenuBarRecentEntriesUsesDefaultsWhenEmpty() {
        let search = EmojiSearch(
            languageCodeProvider: { "en" },
            rankedCharactersProvider: { _, _ in [] },
            recentCharactersProvider: { _ in [] }
        )

        XCTAssertEqual(
            search.menuBarRecentEntries(limit: 12).map(\.character),
            EmojiSearch.menuBarDefaults
        )
    }

    func testMenuBarRecentEntriesPutsRecentsFirstThenPads() {
        let search = EmojiSearch(
            languageCodeProvider: { "en" },
            rankedCharactersProvider: { _, _ in [] },
            recentCharactersProvider: { _ in ["🔥"] }
        )

        let entries = search.menuBarRecentEntries(limit: 12)

        XCTAssertEqual(entries.count, 12)
        XCTAssertEqual(entries.first?.character, "🔥")
        XCTAssertEqual(Set(entries.map(\.character)).count, 12)
    }

    private func makeSearch(
        rankedCharactersProvider: @escaping EmojiSearch.RankedCharactersProvider = { _, _ in [] },
        recentCharactersProvider: @escaping EmojiSearch.RecentCharactersProvider = { _ in [] }
    ) -> EmojiSearch {
        EmojiSearch(
            entries: entries,
            rankedCharactersProvider: rankedCharactersProvider,
            recentCharactersProvider: recentCharactersProvider
        )
    }
}
