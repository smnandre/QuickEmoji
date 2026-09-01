import OSLog

enum AppLogger {
    private static let subsystem = "dev.smnandre.quickemoji"

    static let accessibility = Logger(subsystem: subsystem, category: "Accessibility")
    static let eventTap = Logger(subsystem: subsystem, category: "EventTap")
    static let insertion = Logger(subsystem: subsystem, category: "TextInsertion")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
}
