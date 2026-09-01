import Foundation

@MainActor
enum EmojiLocalizedNames {
    private static var namesByLanguage: [String: [String: String]] = [:]

    static func names(for languageCode: String) -> [String: String] {
        let language = languageCode.lowercased()
        if let names = namesByLanguage[language] {
            return names
        }

        guard
            let url = AppResources.bundle.url(
                forResource: "EmojiNames.\(language)",
                withExtension: "json"
            ),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            namesByLanguage[language] = [:]
            return [:]
        }

        namesByLanguage[language] = file.names
        return file.names
    }

    private struct File: Decodable {
        let names: [String: String]
    }
}
