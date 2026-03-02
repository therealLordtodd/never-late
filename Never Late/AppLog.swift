import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "NeverLate"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let db = Logger(subsystem: subsystem, category: "db")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let ai = Logger(subsystem: subsystem, category: "ai")
}
