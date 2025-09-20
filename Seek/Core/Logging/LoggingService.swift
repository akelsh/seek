import Foundation
import os.log

/// Centralized logging service providing clean, structured logging
class LoggingService {

    // MARK: - Shared Instance

    static let shared = LoggingService()
    private init() {}

    // MARK: - Log Categories

    private let databaseLogger = Logger(subsystem: "com.seek.app", category: "Database")
    private let indexingLogger = Logger(subsystem: "com.seek.app", category: "Indexing")
    private let fileSystemLogger = Logger(subsystem: "com.seek.app", category: "FileSystem")
    private let searchLogger = Logger(subsystem: "com.seek.app", category: "Search")
    private let performanceLogger = Logger(subsystem: "com.seek.app", category: "Performance")
    private let generalLogger = Logger(subsystem: "com.seek.app", category: "General")

    // MARK: - Log Levels

    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case notice = "NOTICE"
        case error = "ERROR"
        case fault = "FAULT"
    }

    // MARK: - Database Logging

    func database(_ level: LogLevel, _ message: String) {
        logMessage(databaseLogger, level, message)
    }

    // MARK: - Indexing Logging

    func indexing(_ level: LogLevel, _ message: String) {
        logMessage(indexingLogger, level, message)
    }

    // MARK: - File System Logging

    func fileSystem(_ level: LogLevel, _ message: String) {
        logMessage(fileSystemLogger, level, message)
    }

    // MARK: - Search Logging

    func search(_ level: LogLevel, _ message: String) {
        logMessage(searchLogger, level, message)
    }

    // MARK: - Performance Logging

    func performance(_ level: LogLevel, _ message: String) {
        logMessage(performanceLogger, level, message)
    }

    // MARK: - General Logging

    func general(_ level: LogLevel, _ message: String) {
        logMessage(generalLogger, level, message)
    }

    // MARK: - Private Implementation

    private func logMessage(_ logger: Logger, _ level: LogLevel, _ message: String) {
        let timestamp = formatTimestamp()
        let formattedMessage = "\(timestamp) \(level.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0)) : \(message)"

        switch level {
        case .debug:
            logger.debug("\(formattedMessage, privacy: .public)")
        case .info:
            logger.info("\(formattedMessage, privacy: .public)")
        case .notice:
            logger.notice("\(formattedMessage, privacy: .public)")
        case .error:
            logger.error("\(formattedMessage, privacy: .public)")
        case .fault:
            logger.fault("\(formattedMessage, privacy: .public)")
        }
    }

    private func formatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}

// MARK: - Convenience Extensions

extension LoggingService {

    // Database convenience methods
    func databaseInfo(_ message: String) { database(.info, message) }
    func databaseError(_ message: String) { database(.error, message) }
    func databaseDebug(_ message: String) { database(.debug, message) }

    // Indexing convenience methods
    func indexingInfo(_ message: String) { indexing(.info, message) }
    func indexingError(_ message: String) { indexing(.error, message) }
    func indexingDebug(_ message: String) { indexing(.debug, message) }

    // File system convenience methods
    func fileSystemInfo(_ message: String) { fileSystem(.info, message) }
    func fileSystemError(_ message: String) { fileSystem(.error, message) }
    func fileSystemDebug(_ message: String) { fileSystem(.debug, message) }

    // Search convenience methods
    func searchInfo(_ message: String) { search(.info, message) }
    func searchError(_ message: String) { search(.error, message) }
    func searchDebug(_ message: String) { search(.debug, message) }

    // Performance convenience methods
    func performanceInfo(_ message: String) { performance(.info, message) }
    func performanceDebug(_ message: String) { performance(.debug, message) }

    // General convenience methods
    func info(_ message: String) { general(.info, message) }
    func error(_ message: String) { general(.error, message) }
    func debug(_ message: String) { general(.debug, message) }
}