import Foundation
import SQLite

// MARK: - Indexing Status Operations

extension DatabaseService {

    // MARK: - Indexing Status Methods

    /// Check if the database has been indexed
    func isIndexed() async throws -> Bool {
        return try await performRead { db in
            let result = try db.scalar("SELECT is_indexed FROM indexing_metadata WHERE id = 1") as? Int64
            return (result ?? 0) != 0
        }
    }

    /// Mark the database as indexed
    func markAsIndexed(paths: [String], fileCount: Int) async throws {
        let pathsData = try JSONEncoder().encode(paths)
        let pathsString = String(data: pathsData, encoding: .utf8) ?? "[]"

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

    // MARK: - Directory Analysis Methods

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

    /// Get all database paths within specific directories
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

    /// Get database paths within a single directory
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
    func clearAllEntries() async throws {
        let _ = try await performWrite { db in
            try db.run("DELETE FROM file_entries")
        }
    }

    /// Get file count
    func getFileCount() async throws -> Int {
        return try await performRead { db in
            let count = try db.scalar("SELECT COUNT(*) FROM file_entries") as! Int64
            return Int(count)
        }
    }
}