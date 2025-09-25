import Foundation
import SQLite

class DatabaseService {

    private let logger = LoggingService.shared
    
    // ------------------
    // MARK: - Properties
    // ------------------

    // Table definition
    private let fileEntries = Table(SeekConfig.Database.Tables.fileEntries)
    private let name = Expression<String>(SeekConfig.Database.Columns.name)
    private let fullPath = Expression<String>(SeekConfig.Database.Columns.fullPath)
    private let isDirectory = Expression<Bool>(SeekConfig.Database.Columns.isDirectory)
    private let fileExtension = Expression<String?>(SeekConfig.Database.Columns.fileExtension)
    private let size = Expression<Int64?>(SeekConfig.Database.Columns.size)
    private let dateModified = Expression<Double>(SeekConfig.Database.Columns.dateModified)

    // Shared instance
    static let shared = DatabaseService()

    // Read and write connections
    private var readConnection: Connection?
    private var writeConnection: Connection?

    // Prepared statements for performance
    private var searchStatement: Statement?
    private var extensionSearchStatement: Statement?

    // Queues for thread safety
    private let readQueue = DispatchQueue(label: SeekConfig.Database.Queues.readQueueLabel, qos: .userInitiated, attributes: .concurrent)
    private let writeQueue = DispatchQueue(label: SeekConfig.Database.Queues.writeQueueLabel, qos: .userInitiated)

    // Path to the sqlite database
    private let dbPath: String

    // ----------------------
    // MARK: - Initialization
    // ----------------------

    private init() {

        // Create app support directory if it doesn't exist

        let seekDirectory = SeekConfig.Database.applicationSupportDirectory

        do {
            try FileManager.default.createDirectory(atPath: seekDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.databaseError("Failed to create directory: \(error)")
            fatalError("Cannot create database directory: \(error)")
        }

        dbPath = SeekConfig.Database.databasePath
        logger.databaseInfo("Database path: \(dbPath)")

        // Setup the connections
        setupConnections()

        // Create the tables
        createTables()

        // Prepare common statements
        prepareStatements()
    }
    
    // ------------------------------
    // MARK: - Initialization Methods
    // ------------------------------

    private func setupConnections() {
        do {
            // Create write connection first to ensure database file exists

            writeConnection = try Connection(dbPath)
            writeConnection?.busyTimeout = SeekConfig.Database.busyTimeout

            // Configure write connection and enable WAL mode

            try writeQueue.sync {
                try writeConnection?.execute(
                """
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

            // Optimize read connection with safe PRAGMA options
            try readQueue.sync {
                try readConnection?.execute(
                """
                    PRAGMA cache_size = \(SeekConfig.Database.ReadConnection.cacheSize);
                    PRAGMA temp_store = \(SeekConfig.Database.ReadConnection.tempStore);
                """)
            }
        } catch {
            logger.databaseError("Database connection error: \(error)")
            fatalError("Failed to setup database connections: \(error)")
        }
    }

    private func createTables() {
        do {
            try writeQueue.sync {
                guard let db = writeConnection else {
                    logger.databaseError("Write connection not available for table creation")
                    return
                }

                // Create the tables
                try db.run(fileEntries.create(ifNotExists: true) { t in
                    t.column(name)
                    t.column(fullPath, unique: true)
                    t.column(isDirectory)
                    t.column(fileExtension)
                    t.column(size)
                    t.column(dateModified)
                })

                // Covering index for search queries - includes all columns we select
                try db.run("CREATE INDEX IF NOT EXISTS idx_name_covering ON file_entries(name COLLATE NOCASE, full_path, is_directory, file_extension, size, date_modified)")

                // Specialized indexes for specific queries
                try db.run("CREATE INDEX IF NOT EXISTS idx_extension ON file_entries(file_extension) WHERE file_extension IS NOT NULL")
                try db.run("CREATE INDEX IF NOT EXISTS idx_date_modified ON file_entries(date_modified)")

                // Create FTS5 virtual table for full-text search
                try db.run(
                """
                    CREATE VIRTUAL TABLE IF NOT EXISTS file_entries_fts USING fts5(
                        name,
                        content='file_entries',
                        content_rowid='rowid',
                        tokenize='unicode61'
                    )
                """)

                // Create triggers to keep FTS table synchronized

                try db.run(
                """
                    CREATE TRIGGER IF NOT EXISTS file_entries_ai AFTER INSERT ON file_entries BEGIN
                        INSERT INTO file_entries_fts(rowid, name) VALUES (NEW.rowid, NEW.name);
                    END
                """)

                try db.run(
                """
                    CREATE TRIGGER IF NOT EXISTS file_entries_ad AFTER DELETE ON file_entries BEGIN
                        INSERT INTO file_entries_fts(file_entries_fts, rowid, name) VALUES('delete', OLD.rowid, OLD.name);
                    END
                """)

                try db.run(
                """
                    CREATE TRIGGER IF NOT EXISTS file_entries_au AFTER UPDATE ON file_entries BEGIN
                        INSERT INTO file_entries_fts(file_entries_fts, rowid, name) VALUES('delete', OLD.rowid, OLD.name);
                        INSERT INTO file_entries_fts(rowid, name) VALUES (NEW.rowid, NEW.name);
                    END
                """)

                // Create indexing metadata table
                try db.run(
                """
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
        } catch {
            logger.databaseError("Table creation error: \(error)")
            fatalError("Failed to create database tables: \(error)")
        }
    }

    private func prepareStatements() {
        do {
            guard let conn = readConnection else { return }

            searchStatement = try conn.prepare(
            """
                SELECT f.* FROM file_entries f
                JOIN file_entries_fts fts ON f.rowid = fts.rowid
                WHERE fts.name MATCH ?
                ORDER BY LENGTH(f.name), f.name
                LIMIT ?
            """)

            extensionSearchStatement = try conn.prepare(
            """
                SELECT * FROM file_entries
                WHERE file_extension = ?
                ORDER BY name
                LIMIT ?
            """)

            logger.databaseInfo("Prepared statements created successfully")
        } catch {
            logger.databaseError("Failed to prepare statements: \(error)")
        }
    }
    
    // -----------------------------
    // MARK: - Connection Management
    // -----------------------------

    func closeConnections() {
        searchStatement = nil
        extensionSearchStatement = nil
        readConnection = nil
        writeConnection = nil
    }
    
    // ---------------------------------
    // MARK: - Async Database Operations
    // ---------------------------------

    func performRead<T>(_ operation: @escaping (Connection) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            readQueue.async {
                do {
                    guard let connection = self.readConnection else {
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

    func performWrite<T>(_ operation: @escaping (Connection) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            writeQueue.async {
                do {
                    guard let connection = self.writeConnection else {
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
    
    // -----------------------
    // MARK: - Bulk Operations
    // -----------------------

    func insertBatch(_ entries: [FileEntry]) async throws {
        try await performWrite { db in
            let insertSQL = 
            """
                INSERT OR IGNORE INTO file_entries (name, full_path, is_directory, file_extension, size, date_modified)
                VALUES (?, ?, ?, ?, ?, ?)
            """

            let statement = try db.prepare(insertSQL)

            for entry in entries {
                try statement.run(
                    entry.name,
                    entry.fullPath,
                    entry.isDirectory,
                    entry.fileExtension,
                    entry.size,
                    entry.dateModified
                )
            }
        }
    }

    func beginBulkIndexing() async throws {
        try await performWrite { db in

            // Fast but safe settings for bulk indexing
            try db.execute(
            """
                PRAGMA synchronous = \(SeekConfig.Database.BulkIndexing.synchronous);
                PRAGMA cache_size = \(SeekConfig.Database.BulkIndexing.cacheSize);
                PRAGMA temp_store = \(SeekConfig.Database.BulkIndexing.tempStore);
                PRAGMA mmap_size = \(SeekConfig.Database.BulkIndexing.mmapSize);
            """)

            try db.execute("BEGIN TRANSACTION")
        }
    }

    func commitBulkIndexing() async throws {
        try await performWrite { db in
            try db.execute("COMMIT")

            // Restore safe settings
            try db.execute(
            """
                PRAGMA synchronous = NORMAL;
                PRAGMA journal_mode = WAL;
            """)

            // Optimize after bulk insert
            try db.execute("VACUUM")
            try db.execute("ANALYZE")
        }
    }

    func getFileCount() async throws -> Int {
        return try await performRead { db in
            let count = try db.scalar("SELECT COUNT(*) FROM file_entries") as! Int64
            return Int(count)
        }
    }
    
    // ---------------------------
    // MARK: - Incremental Updates
    // ---------------------------

    /// Insert or update a single file entry
    func upsertEntry(_ entry: FileEntry) async throws {
        try await performWrite { db in
            let sql =
            """
                INSERT OR REPLACE INTO file_entries (name, full_path, is_directory, file_extension, size, date_modified)
                VALUES (?, ?, ?, ?, ?, ?)
            """

            let statement = try db.prepare(sql)
            try statement.run(
                entry.name,
                entry.fullPath,
                entry.isDirectory,
                entry.fileExtension,
                entry.size,
                entry.dateModified
            )

            self.logger.databaseDebug("Upserted entry: \(entry.name)")
        }
    }

    // -------------------------------
    // MARK: - Indexing Status Methods
    // -------------------------------

    /// Check if the database has been indexed
    func isIndexed() async throws -> Bool {
        return try await performRead { db in
            let sql = "SELECT is_indexed FROM indexing_metadata WHERE id = 1"
            let result = try db.scalar(sql) as? Int64 ?? 0
            return result != 0
        }
    }

    /// Get the last indexing timestamp
    func getLastIndexedDate() async throws -> Date? {
        return try await performRead { db in
            let sql = "SELECT last_indexed_date FROM indexing_metadata WHERE id = 1"
            let result = try db.scalar(sql) as? Double
            return result.map { Date(timeIntervalSince1970: $0) }
        }
    }

    /// Mark the database as indexed with metadata
    func markAsIndexed(paths: [String], fileCount: Int) async throws {
        let pathsJson = try JSONEncoder().encode(paths)
        let pathsString = String(data: pathsJson, encoding: .utf8) ?? "[]"

        try await performWrite { db in
            let sql = """
                UPDATE indexing_metadata
                SET is_indexed = 1,
                    last_indexed_date = ?,
                    indexed_paths = ?,
                    total_files_indexed = ?
                WHERE id = 1
            """
            try db.run(sql, Date().timeIntervalSince1970, pathsString, fileCount)
        }
    }

    /// Get detailed indexing status information
    func getIndexingStatus() async throws -> (isIndexed: Bool, lastIndexedDate: Date?, indexedPaths: [String], fileCount: Int) {
        return try await performRead { db in
            let sql = "SELECT is_indexed, last_indexed_date, indexed_paths, total_files_indexed FROM indexing_metadata WHERE id = 1"
            let statement = try db.prepare(sql)

            for row in try statement.run() {
                let isIndexed = (row[0] as? Int64 ?? 0) != 0
                let lastIndexedTimestamp = row[1] as? Double
                let lastIndexedDate = lastIndexedTimestamp.map { Date(timeIntervalSince1970: $0) }
                let pathsString = row[2] as? String ?? "[]"
                let fileCount = Int(row[3] as? Int64 ?? 0)

                let indexedPaths: [String]
                if let pathsData = pathsString.data(using: .utf8) {
                    indexedPaths = (try? JSONDecoder().decode([String].self, from: pathsData)) ?? []
                } else {
                    indexedPaths = []
                }

                return (isIndexed, lastIndexedDate, indexedPaths, fileCount)
            }

            return (false, nil, [], 0)
        }
    }

    /// Clear indexing status (for full reindex)
    func clearIndexingStatus() async throws {
        try await performWrite { db in
            let sql = """
                UPDATE indexing_metadata
                SET is_indexed = 0,
                    last_indexed_date = NULL,
                    indexed_paths = NULL,
                    total_files_indexed = 0
                WHERE id = 1
            """
            try db.run(sql)
        }
    }
    
    // --------------------------------
    // MARK: - Smart Reindexing Methods
    // --------------------------------

    /// Get all file paths currently in the database
    func getAllDatabasePaths() async throws -> Set<String> {
        return try await performRead { db in
            let sql = "SELECT full_path FROM file_entries"
            let statement = try db.prepare(sql)
            var paths = Set<String>()

            for row in try statement.run() {
                let path = row[0] as! String
                paths.insert(path)
            }

            return paths
        }
    }

    func getAllDatabasePathsInDirectories(_ directories: [String]) async throws -> Set<String> {
        return try await performRead { db in
            var paths = Set<String>()

            for directory in directories {
                let sql = "SELECT full_path FROM file_entries WHERE full_path LIKE ? || '%'"
                let statement = try db.prepare(sql)
                for row in try statement.run(directory) {
                    let path = row[0] as! String
                    paths.insert(path)
                }
            }
            return paths
        }
    }

    func getDatabasePathsInDirectory(_ directory: String) async throws -> Set<String> {
        return try await performRead { db in
            let sql = "SELECT full_path FROM file_entries WHERE full_path LIKE ? || '%'"
            let statement = try db.prepare(sql)
            var paths = Set<String>()
            for row in try statement.run(directory) {
                let path = row[0] as! String
                paths.insert(path)
            }
            return paths
        }
    }

    /// Clear all file entries from the database (for full reindex)
    func clearAllFileEntries() async throws {
        _ = try await performWrite { db in
            try db.run("DELETE FROM file_entries")
        }
    }

    /// Fastest way to clear database - delete file and recreate
    func recreateDatabase() async throws {
        // Close all connections first
        closeConnections()

        // Delete the database file
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: dbPath) {
            try fileManager.removeItem(atPath: dbPath)
        }

        // Also remove WAL and SHM files if they exist
        let walPath = dbPath + "-wal"
        let shmPath = dbPath + "-shm"

        if fileManager.fileExists(atPath: walPath) {
            try fileManager.removeItem(atPath: walPath)
        }

        if fileManager.fileExists(atPath: shmPath) {
            try fileManager.removeItem(atPath: shmPath)
        }

        // Recreate connections and tables
        setupConnections()
        createTables()
        prepareStatements()
    }

    /// Remove all entries with a specific path prefix (for directory deletion)
    func deleteAllEntriesWithPathPrefix(_ pathPrefix: String) async throws {
        try await performWrite { db in
            let sql = "DELETE FROM file_entries WHERE full_path LIKE ? || '%'"
            try db.run(sql, pathPrefix)
        }
    }

    /// Batch remove multiple paths efficiently
    func batchRemovePaths(_ paths: [String]) async throws {
        guard !paths.isEmpty else { return }

        try await performWrite { db in
            let sql = "DELETE FROM file_entries WHERE full_path = ?"
            let statement = try db.prepare(sql)

            for path in paths {
                try statement.run(path)
            }
        }
    }

    /// Update last indexed date without changing indexed status
    func updateLastIndexedDate() async throws {
        try await performWrite { db in
            let sql = """
                UPDATE indexing_metadata
                SET last_indexed_date = ?
                WHERE id = 1
            """
            try db.run(sql, Date().timeIntervalSince1970)
        }
    }

    /// Store the last processed FSEvent ID
    func storeLastEventId(_ eventId: FSEventStreamEventId) async throws {
        try await performWrite { db in
            let sql = """
                UPDATE indexing_metadata
                SET last_event_id = ?
                WHERE id = 1
            """
            try db.run(sql, Int64(eventId))
        }
    }

    /// Get the last processed FSEvent ID
    func getLastEventId() async throws -> FSEventStreamEventId? {
        return try await performRead { db in
            let sql = "SELECT last_event_id FROM indexing_metadata WHERE id = 1"
            let result = try db.scalar(sql) as? Int64
            return result.map { FSEventStreamEventId($0) }
        }
    }

    /// Clear the stored event ID (for full reindex)
    func clearLastEventId() async throws {
        try await performWrite { db in
            let sql = """
                UPDATE indexing_metadata
                SET last_event_id = NULL
                WHERE id = 1
            """
            try db.run(sql)
        }
    }

    /// Batch upsert file entries for smart reindexing
    func batchUpsertEntries(_ entries: [FileEntry]) async throws {
        guard !entries.isEmpty else { return }

        try await performWrite { db in
            let sql = """
                INSERT OR REPLACE INTO file_entries (name, full_path, is_directory, file_extension, size, date_modified)
                VALUES (?, ?, ?, ?, ?, ?)
            """
            let statement = try db.prepare(sql)

            for entry in entries {
                try statement.run(
                    entry.name,
                    entry.fullPath,
                    entry.isDirectory,
                    entry.fileExtension,
                    entry.size,
                    entry.dateModified
                )
            }
        }
    }
}

// -------------------
// MARK: - Error Types
// -------------------

enum DatabaseError: Error {
    case connectionUnavailable
}
