import Foundation
import SQLite

/// Manages database connections with proper setup, configuration, and lifecycle management
final class DatabaseConnectionManager: @unchecked Sendable {

    // ------------------
    // MARK: - Properties
    // ------------------

    private let logger = LoggingService.shared
    private let dbPath: String
    private let readQueue = DispatchQueue(label: SeekConfig.Database.Queues.readQueueLabel, qos: .userInitiated, attributes: .concurrent)
    private let writeQueue = DispatchQueue(label: SeekConfig.Database.Queues.writeQueueLabel, qos: .userInitiated)

    // Connection state
    private var readConnection: Connection?
    private var writeConnection: Connection?
    private var isInitialized: Bool = false
    private var initializationError: Error?

    // ----------------------
    // MARK: - Initialization
    // ----------------------

    init(databasePath: String) throws {
        self.dbPath = databasePath

        // Ensure database directory exists
        let directory = (databasePath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)

        // Setup connections
        try setupConnections()
        isInitialized = true
    }
    
    // ------------------------
    // MARK: - Connection Setup
    // ------------------------

    private func setupConnections() throws {
        do {
            // Create write connection first to ensure database file exists
            writeConnection = try Connection(dbPath)
            writeConnection?.busyTimeout = SeekConfig.Database.busyTimeout

            // Configure write connection and enable WAL mode
            try writeQueue.sync {
                try writeConnection?.execute("""
                    PRAGMA journal_mode = \(SeekConfig.Database.WriteConnection.journalMode);
                    PRAGMA synchronous = \(SeekConfig.Database.WriteConnection.synchronous);
                    PRAGMA cache_size = \(SeekConfig.Database.WriteConnection.cacheSize);
                    PRAGMA temp_store = \(SeekConfig.Database.WriteConnection.tempStore);
                    PRAGMA mmap_size = \(SeekConfig.Database.WriteConnection.mmapSize);
                    PRAGMA wal_autocheckpoint = \(SeekConfig.Database.WriteConnection.walAutocheckpoint);
                """)
            }

            // Force a checkpoint to ensure WAL file is created properly
            try writeConnection?.execute("PRAGMA wal_checkpoint(TRUNCATE)")

            // Now create read connection after WAL is properly initialized
            readConnection = try Connection(dbPath, readonly: true)
            readConnection?.busyTimeout = SeekConfig.Database.busyTimeout

            // Configure read connection
            try readQueue.sync {
                try readConnection?.execute("""
                    PRAGMA cache_size = \(SeekConfig.Database.ReadConnection.cacheSize);
                    PRAGMA temp_store = \(SeekConfig.Database.ReadConnection.tempStore);
                """)
            }

            logger.databaseInfo("Database connections established successfully")
        } catch {
            logger.databaseError("Connection setup error: \(error)")
            throw DatabaseError.connectionSetupFailed(error)
        }
    }
    
    // -------------------------
    // MARK: - Connection Access
    // -------------------------

    /// Check if connections are properly initialized
    func isConnectionsReady() -> Bool {
        return isInitialized && readConnection != nil && writeConnection != nil
    }

    /// Get initialization error if any
    func getInitializationError() -> Error? {
        return initializationError
    }
    
    // ---------------------------
    // MARK: - Database Operations
    // ---------------------------

    /// Perform a read operation with proper queue management
    func performRead<T>(_ operation: @escaping (Connection) throws -> T) async throws -> T {
        guard isConnectionsReady() else {
            if let error = initializationError {
                throw error
            }
            throw DatabaseError.connectionUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            readQueue.async { [weak self] in
                do {
                    guard let self = self, let connection = self.readConnection else {
                        continuation.resume(throwing: DatabaseError.connectionUnavailable)
                        return
                    }
                    let result = try operation(connection)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Perform a write operation with proper queue management
    func performWrite<T>(_ operation: @escaping (Connection) throws -> T) async throws -> T {
        guard isConnectionsReady() else {
            if let error = initializationError {
                throw error
            }
            throw DatabaseError.connectionUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            writeQueue.async { [weak self] in
                do {
                    guard let self = self, let connection = self.writeConnection else {
                        continuation.resume(throwing: DatabaseError.connectionUnavailable)
                        return
                    }
                    let result = try operation(connection)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // ----------------------------
    // MARK: - Connection Lifecycle
    // ----------------------------

    /// Close all database connections
    func closeConnections() {
        writeQueue.async { [weak self] in
            self?.writeConnection = nil
        }

        readQueue.sync { [weak self] in
            self?.readConnection = nil
        }

        isInitialized = false
        logger.databaseInfo("Database connections closed")
    }

    /// Reconnect if connections are lost
    func reconnectIfNeeded() throws {
        guard !isConnectionsReady() else { return }

        logger.databaseInfo("Attempting to reconnect database connections")
        try setupConnections()
        isInitialized = true
    }
    
    // --------------------
    // MARK: - Health Check
    // --------------------

    /// Check if connections are healthy by performing a simple query
    func healthCheck() async throws -> Bool {
        do {
            let _ = try await performRead { connection in
                return try connection.scalar("SELECT 1") as? Int64
            }
            return true
        } catch {
            logger.databaseError("Database health check failed: \(error)")
            return false
        }
    }
    
    // -----------------------------
    // MARK: - Connection Statistics
    // -----------------------------

    /// Get connection statistics for monitoring
    func getConnectionStats() -> (readQueue: String, writeQueue: String, isReady: Bool) {
        return (
            readQueue: SeekConfig.Database.Queues.readQueueLabel,
            writeQueue: SeekConfig.Database.Queues.writeQueueLabel,
            isReady: isConnectionsReady()
        )
    }
}
