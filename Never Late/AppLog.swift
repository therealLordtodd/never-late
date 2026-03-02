import Foundation
import os

enum AppLogLevel: Int, CaseIterable, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    static func < (lhs: AppLogLevel, rhs: AppLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum AppLogVerbosity: String, CaseIterable, Identifiable, Sendable {
    case errorsOnly
    case warnings
    case info
    case verbose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .errorsOnly: return "Errors Only"
        case .warnings: return "Warnings + Errors"
        case .info: return "Info + Warnings + Errors"
        case .verbose: return "Verbose (Debug)"
        }
    }

    fileprivate var minimumLevel: AppLogLevel {
        switch self {
        case .errorsOnly: return .error
        case .warnings: return .warning
        case .info: return .info
        case .verbose: return .debug
        }
    }
}

private struct AppLogRuntimeState {
    var enabled: Bool
    var minimumLevel: AppLogLevel
}

private final class AppLogRuntime {
    static let shared = AppLogRuntime()

    private let lock = NSLock()
    private let buildAllowsLogging: Bool
    private var state: AppLogRuntimeState

    private init() {
        buildAllowsLogging = Self.resolveBuildLoggingPolicy()
        state = AppLogRuntimeState(
            enabled: Self.defaultEnabled,
            minimumLevel: AppLogVerbosity.info.minimumLevel
        )
    }

    func configure(enabled: Bool, minimumLevel: AppLogLevel) {
        lock.lock()
        state.enabled = enabled
        state.minimumLevel = minimumLevel
        lock.unlock()
    }

    func shouldEmit(_ level: AppLogLevel) -> Bool {
        lock.lock()
        let snapshot = state
        lock.unlock()
        guard buildAllowsLogging else { return false }
        guard snapshot.enabled else { return false }
        return level >= snapshot.minimumLevel
    }

    func diagnosticsEnabled() -> Bool {
        lock.lock()
        let enabled = state.enabled
        lock.unlock()
        return buildAllowsLogging && enabled
    }

    func currentMinimumLevel() -> AppLogLevel {
        lock.lock()
        let level = state.minimumLevel
        lock.unlock()
        return level
    }

    func buildAllowsDiagnostics() -> Bool {
        buildAllowsLogging
    }

    private static var defaultEnabled: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }

    private static func resolveBuildLoggingPolicy() -> Bool {
        if let override = Bundle.main.object(forInfoDictionaryKey: "NLAllowDiagnosticLogging") as? Bool {
            return override
        }
#if DEBUG
        return true
#else
        return false
#endif
    }
}

struct AppCategoryLog {
    private let logger: Logger

    fileprivate init(subsystem: String, category: String) {
        logger = Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String, metadata: [String: String] = [:]) {
        AppLog.emit(level: .debug, logger: logger, message: message, metadata: metadata)
    }

    func info(_ message: String, metadata: [String: String] = [:]) {
        AppLog.emit(level: .info, logger: logger, message: message, metadata: metadata)
    }

    func warning(_ message: String, metadata: [String: String] = [:]) {
        AppLog.emit(level: .warning, logger: logger, message: message, metadata: metadata)
    }

    func error(_ message: String, metadata: [String: String] = [:]) {
        AppLog.emit(level: .error, logger: logger, message: message, metadata: metadata)
    }
}

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "NeverLate"
    private static let runtime = AppLogRuntime.shared

    static let app = AppCategoryLog(subsystem: subsystem, category: "app")
    static let ui = AppCategoryLog(subsystem: subsystem, category: "ui")
    static let db = AppCategoryLog(subsystem: subsystem, category: "db")
    static let network = AppCategoryLog(subsystem: subsystem, category: "network")
    static let auth = AppCategoryLog(subsystem: subsystem, category: "auth")
    static let ai = AppCategoryLog(subsystem: subsystem, category: "ai")

    static var buildAllowsDiagnostics: Bool {
        runtime.buildAllowsDiagnostics()
    }

    static var diagnosticsEnabled: Bool {
        runtime.diagnosticsEnabled()
    }

    static var minimumLevel: AppLogLevel {
        runtime.currentMinimumLevel()
    }

    static func configureFromDefaults() {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: SettingsKeys.loggingEnabled) as? Bool
            ?? defaultLoggingEnabled
        let verbosityRaw = defaults.string(forKey: SettingsKeys.loggingVerbosity)
            ?? defaultLoggingVerbosity.rawValue
        let verbosity = AppLogVerbosity(rawValue: verbosityRaw) ?? defaultLoggingVerbosity
        configure(enabled: enabled, verbosity: verbosity)
    }

    static func configure(enabled: Bool, verbosity: AppLogVerbosity) {
        runtime.configure(enabled: enabled, minimumLevel: verbosity.minimumLevel)
    }

    fileprivate static func emit(
        level: AppLogLevel,
        logger: Logger,
        message: String,
        metadata: [String: String]
    ) {
        guard runtime.shouldEmit(level) else { return }
        let formattedMessage = decorate(message: message, metadata: metadata)
        switch level {
        case .debug:
            logger.debug("\(formattedMessage)")
        case .info:
            logger.info("\(formattedMessage)")
        case .warning:
            logger.warning("\(formattedMessage)")
        case .error:
            logger.error("\(formattedMessage)")
        }
    }

    private static func decorate(message: String, metadata: [String: String]) -> String {
        guard metadata.isEmpty == false else { return message }
        let tags = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return "\(message) [\(tags)]"
    }

    private static var defaultLoggingEnabled: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }

    private static var defaultLoggingVerbosity: AppLogVerbosity {
#if DEBUG
        return .verbose
#else
        return .warnings
#endif
    }
}
