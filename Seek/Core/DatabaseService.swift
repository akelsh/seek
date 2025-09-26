import Foundation
import SQLite

final class DatabaseService: @unchecked Sendable {

    internal let logger = LoggingService.shared

    // ------------------
    // MARK: - Properties
    // ------------------

    // Shared instance
    static let shared = DatabaseService()

    // Connection manager
    private let connectionManager: DatabaseConnectionManager

    // Internal table references for extensions
    internal let fileEntries = Table(SeekConfig.Database.Tables.fileEntries)

    // ----------------------
    // MARK: - Initialization
    // ----------------------

    private init() {
        do {
            // Initialize connection manager
            let dbPath = SeekConfig.Database.databasePath
            logger.databaseInfo("Database path: \(dbPath)")

            connectionManager = try DatabaseConnectionManager(databasePath: dbPath)

            // Create the tables asynchronously after initialization
            Task {
                do {
                    try await createTables()
                    logger.databaseInfo("Database tables created successfully")
                } catch {
                    logger.databaseError("Failed to create tables: \(error)")
                }
            }
        } catch {
            logger.databaseError("Failed to initialize database: \(error)")
            // Use a dummy connection manager that always fails
            connectionManager = try! DatabaseConnectionManager(databasePath: "/dev/null")
            // Store error in connection manager for later retrieval
        }
    }

    // ------------------------------
    // MARK: - Table Setup Methods
    // ------------------------------

    private func createTables() async throws {
        try await connectionManager.performWrite { db in
            // Create main file_entries table
            try db.run("""
                CREATE TABLE IF NOT EXISTS file_entries (
                    name TEXT NOT NULL,
                    full_path TEXT NOT NULL UNIQUE,
                    is_directory BOOLEAN NOT NULL,
                    file_extension TEXT,
                    size INTEGER,
                    date_modified REAL NOT NULL
                )
            """)

            // Create indexes for performance
            try db.run("CREATE INDEX IF NOT EXISTS \(SeekConfig.Database.Indexes.name) ON file_entries(name)")
            try db.run("CREATE INDEX IF NOT EXISTS \(SeekConfig.Database.Indexes.fileExtension) ON file_entries(file_extension)")
            try db.run("CREATE INDEX IF NOT EXISTS \(SeekConfig.Database.Indexes.size) ON file_entries(size)")
            try db.run("CREATE INDEX IF NOT EXISTS \(SeekConfig.Database.Indexes.dateModified) ON file_entries(date_modified)")
            try db.run("CREATE INDEX IF NOT EXISTS \(SeekConfig.Database.Indexes.isDirectory) ON file_entries(is_directory)")

            // Create FTS virtual table for fast text search
            try db.run("""
                CREATE VIRTUAL TABLE IF NOT EXISTS file_entries_fts USING fts5(
                    name,
                    tokenize='\(SeekConfig.Database.FTS.tokenizer)'
                )
            """)

            // Create triggers to keep FTS table synchronized
            try db.run("""
                CREATE TRIGGER IF NOT EXISTS file_entries_ai AFTER INSERT ON file_entries BEGIN
                    INSERT INTO file_entries_fts(rowid, name) VALUES (NEW.rowid, NEW.name);
                END
            """)

            try db.run("""
                CREATE TRIGGER IF NOT EXISTS file_entries_ad AFTER DELETE ON file_entries BEGIN
                    INSERT INTO file_entries_fts(file_entries_fts, rowid, name) VALUES('delete', OLD.rowid, OLD.name);
                END
            """)

            try db.run("""
                CREATE TRIGGER IF NOT EXISTS file_entries_au AFTER UPDATE ON file_entries BEGIN
                    INSERT INTO file_entries_fts(file_entries_fts, rowid, name) VALUES('delete', OLD.rowid, OLD.name);
                    INSERT INTO file_entries_fts(rowid, name) VALUES (NEW.rowid, NEW.name);
                END
            """)

            // Create indexing metadata table
            try db.run("""
                CREATE TABLE IF NOT EXISTS indexing_metadata (
                    id INTEGER PRIMARY KEY,
                    is_indexed BOOLEAN NOT NULL DEFAULT 0,
                    last_indexed_date REAL,
                    indexed_paths TEXT,
                    total_files_indexed INTEGER DEFAULT 0,
                    indexing_version INTEGER DEFAULT 1,
                    last_event_id INTEGER
                )
            """)

            // Initialize metadata tables with default values if empty
            try db.run("INSERT OR IGNORE INTO indexing_metadata (id, is_indexed) VALUES (1, 0)")
        }
    }

    // -----------------------------
    // MARK: - Connection Management
    // -----------------------------

    /// Check if the database was properly initialized
    func isInitialized() -> Bool {
        return connectionManager.isConnectionsReady()
    }

    /// Get initialization error if any
    func getInitializationError() -> Error? {
        return connectionManager.getInitializationError()
    }

    func closeConnections() {
        connectionManager.closeConnections()
    }

    // ---------------------------------
    // MARK: - Async Database Operations
    // ---------------------------------

    func performRead<T>(_ operation: @escaping (Connection) throws -> T) async throws -> T {
        return try await connectionManager.performRead(operation)
    }

    func performWrite<T>(_ operation: @escaping (Connection) throws -> T) async throws -> T {
        return try await connectionManager.performWrite(operation)
    }
}