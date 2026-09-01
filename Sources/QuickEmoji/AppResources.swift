import Foundation

enum AppResources {
    static let bundle: Bundle = {
        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("QuickEmoji_QuickEmoji.bundle"),
            let bundle = Bundle(url: resourceURL)
        {
            return bundle
        }

        return .module
    }()
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static let githubURL = "https://github.com/smnandre/QuickEmoji"
    static let websiteURL = URL(string: "https://smnand.re/quickemoji")!
    static let publishedCaskURL = URL(
        string: "https://raw.githubusercontent.com/smnandre/homebrew-tap/main/Casks/quickemoji.rb"
    )!
    static let homebrewUpgradeCommand = "brew upgrade --cask quickemoji"
}
