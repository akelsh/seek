import Foundation

enum SeekConfig {
    
    // ------------------------------
    // MARK: - Database Configuration
    // ------------------------------

    enum Database {
        static let fileName = "file_indexing_table.db"
        static let appName = "Seek"

        // Connection settings
        static let busyTimeout: Double = 30.0

        // Write connection PRAGMA settings
        enum WriteConnection {
            static let synchronous = "NORMAL"
            static let journalMode = "WAL"
            static let cacheSize = -64_000  // 64MB in KB (negative for KB)
            static let tempStore = "MEMORY"
            static let mmapSize: Int64 = 30_000_000_000  // 30GB
            static let walAutocheckpoint = 10_000
        }

        // Read connection PRAGMA settings
        enum ReadConnection {
            static let cacheSize = -200_000  // 200MB in KB
            static let tempStore = "MEMORY"
        }

        // Bulk indexing PRAGMA settings
        enum BulkIndexing {
            static let synchronous = "OFF"
            static let cacheSize = -256_000  // 256MB in KB
            static let tempStore = "MEMORY"
            static let mmapSize: Int64 = 2_147_483_648  // 2GB
        }

        // Queue configuration
        enum Queues {
            static let readQueueLabel = "com.akelsh.seek.db.read"
            static let writeQueueLabel = "com.akelsh.seek.db.write"
        }

        // Table names
        enum Tables {
            static let fileEntries = "file_entries"
            static let fileEntriesFTS = "file_entries_fts"
        }

        // Column names
        enum Columns {
            static let name = "name"
            static let fullPath = "full_path"
            static let isDirectory = "is_directory"
            static let fileExtension = "file_extension"
            static let size = "size"
            static let dateModified = "date_modified"
        }

        // Index names
        enum Indexes {
            static let name = "idx_name"
            static let fileExtension = "idx_extension"
            static let size = "idx_size"
            static let dateModified = "idx_date_modified"
            static let isDirectory = "idx_is_directory"
        }

        // FTS configuration
        enum FTS {
            static let tokenizer = "unicode61"
        }

        // Search limits
        static let defaultSearchLimit = 1000
    }
    
    // ------------------------------
    // MARK: - Indexing Configuration
    // ------------------------------

    enum Indexing {
        static let batchSize = 50_000

        // Single root scanning - let work queue handle distribution
        static let defaultScanPaths = ["/"]

        // Concurrency configuration for different operations
        enum Concurrency {
            static let fullIndexing = 8        // Full indexing workers (mixed I/O + DB)
            static let findingChanges = 6      // Directory change detection workers (I/O bound)
            static let rebuildingDirs = 4      // Directory rebuilding workers (CPU + DB bound)
        }

        // Resource keys to fetch
        static let resourceKeys: [URLResourceKey] = [
            .nameKey,
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isSymbolicLinkKey,
            .fileResourceIdentifierKey
        ]
    }
    
    // ---------------------------------
    // MARK: - Application Configuration
    // ---------------------------------

    enum App {
        static let applicationSupportSubdirectory = "Seek"
    }
}

// ---------------------------
// MARK: - Computed Properties
// ---------------------------

extension SeekConfig.Database {
    static var databasePath: String {
        let appSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        let seekDirectory = "\(appSupportPath)/\(SeekConfig.App.applicationSupportSubdirectory)"
        return "\(seekDirectory)/\(fileName)"
    }

    static var applicationSupportDirectory: String {
        let appSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        return "\(appSupportPath)/\(SeekConfig.App.applicationSupportSubdirectory)"
    }
}
