import Foundation
import SQLite

// ------------------------
// MARK: - Batch Operations
// ------------------------

extension DatabaseService {
    
    // ------------------------------
    // MARK: - Bulk Insert Operations
    // ------------------------------

    /// Insert a batch of entries (ignoring duplicates)
    func insertBatch(_ entries: [FileEntry]) async throws {
        try await performWrite { db in
            let insertSQL = """
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

    /// Remove multiple entries by path
    func batchRemoveEntries(_ paths: [String]) async throws {
        guard !paths.isEmpty else { return }

        try await performWrite { db in
            let sql = "DELETE FROM file_entries WHERE full_path = ?"
            let statement = try db.prepare(sql)

            for path in paths {
                try statement.run(path)
            }
        }
    }

    // MARK: - Bulk Transaction Management

    /// Begin optimized bulk indexing mode
    func beginBulkIndexing() async throws {
        try await performWrite { db in
            // Fast but safe settings for bulk indexing
            try db.execute("""
                PRAGMA synchronous = \(SeekConfig.Database.BulkIndexing.synchronous);
                PRAGMA cache_size = \(SeekConfig.Database.BulkIndexing.cacheSize);
                PRAGMA temp_store = \(SeekConfig.Database.BulkIndexing.tempStore);
                PRAGMA mmap_size = \(SeekConfig.Database.BulkIndexing.mmapSize);
            """)

            try db.execute("BEGIN TRANSACTION")
        }
    }

    /// Commit bulk indexing and restore normal settings
    func commitBulkIndexing() async throws {
        try await performWrite { db in
            try db.execute("COMMIT")

            // Restore safe settings
            try db.execute("""
                PRAGMA synchronous = NORMAL;
                PRAGMA journal_mode = WAL;
            """)

            // Optimize after bulk insert
            try db.execute("VACUUM")
            try db.execute("ANALYZE")
        }
    }

    /// Rollback bulk indexing transaction
    func rollbackBulkIndexing() async throws {
        try await performWrite { db in
            try db.execute("ROLLBACK")

            // Restore safe settings
            try db.execute("""
                PRAGMA synchronous = NORMAL;
                PRAGMA journal_mode = WAL;
            """)
        }
    }

    // MARK: - Incremental Update Operations

    /// Insert or update a single file entry
    func upsertEntry(_ entry: FileEntry) async throws {
        try await performWrite { db in
            let sql = """
                INSERT OR REPLACE INTO file_entries (name, full_path, is_directory, file_extension, size, date_modified)
                VALUES (?, ?, ?, ?, ?, ?)
            """
            try db.run(sql, entry.name, entry.fullPath, entry.isDirectory, entry.fileExtension, entry.size, entry.dateModified)
        }
    }

    /// Remove a single entry by path
    func removeEntry(at path: String) async throws {
        let _ = try await performWrite { db in
            try db.run("DELETE FROM file_entries WHERE full_path = ?", path)
        }
    }

    /// Remove all entries under a directory path
    func removeEntriesUnderPath(_ path: String) async throws {
        try await performWrite { db in
            let sql = "DELETE FROM file_entries WHERE full_path LIKE ? || '%'"
            try db.run(sql, path)
        }
    }
    
    // ----------------------------
    // MARK: - Database Maintenance
    // ----------------------------

    /// Vacuum the database to reclaim space
    func vacuumDatabase() async throws {
        try await performWrite { db in
            try db.execute("VACUUM")
        }
    }

    /// Analyze the database to update statistics
    func analyzeDatabase() async throws {
        try await performWrite { db in
            try db.execute("ANALYZE")
        }
    }

    /// Checkpoint the WAL file
    func checkpointWAL() async throws {
        try await performWrite { db in
            try db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    /// Optimize database (vacuum + analyze + checkpoint)
    func optimizeDatabase() async throws {
        try await performWrite { db in
            try db.execute("VACUUM")
            try db.execute("ANALYZE")
            try db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    /// Recreate the database by clearing all entries and resetting metadata
    func recreateDatabase() async throws {
        try await performWrite { db in
            // Clear all file entries
            try db.execute("DELETE FROM file_entries")

            // Reset indexing metadata
            try db.execute("""
                UPDATE indexing_metadata
                SET is_indexed = 0,
                    last_indexed_date = NULL,
                    indexed_paths = NULL,
                    total_files_indexed = 0,
                    last_event_id = NULL
                WHERE id = 1
            """)

            // Vacuum to reclaim space
            try db.execute("VACUUM")
        }
    }
}
