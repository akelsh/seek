import Foundation
import SQLite

// MARK: - Search Operations

extension DatabaseService {

    // MARK: - Search Methods

    /// Search for files by name using full-text search
    func searchFiles(query: String, limit: Int = SeekConfig.Database.defaultSearchLimit) async throws -> [FileEntry] {
        // Sanitize query for FTS
        let sanitizedQuery = query.replacingOccurrences(of: "\"", with: "\"\"")
        let ftsQuery = "\(sanitizedQuery)*"

        return try await performRead { db in
            let sql = """
                SELECT f.* FROM file_entries f
                JOIN file_entries_fts fts ON f.rowid = fts.rowid
                WHERE fts.name MATCH ?
                ORDER BY LENGTH(f.name), f.name
                LIMIT ?
            """

            let statement = try db.prepare(sql)
            var results: [FileEntry] = []

            for row in try statement.run(ftsQuery, limit) {
                do {
                    let entry = try self.parseFileEntry(from: row)
                    results.append(entry)
                } catch {
                    // Log parsing error but continue processing other rows
                    self.logger.searchError("Failed to parse search result: \(error)")
                }
            }

            return results
        }
    }


    /// Search for directories only
    func searchDirectories(query: String, limit: Int = SeekConfig.Database.defaultSearchLimit) async throws -> [FileEntry] {
        let sanitizedQuery = query.replacingOccurrences(of: "\"", with: "\"\"")
        let ftsQuery = "\(sanitizedQuery)*"

        return try await performRead { db in
            let sql = """
                SELECT f.* FROM file_entries f
                JOIN file_entries_fts fts ON f.rowid = fts.rowid
                WHERE fts.name MATCH ? AND f.is_directory = 1
                ORDER BY LENGTH(f.name), f.name
                LIMIT ?
            """

            let statement = try db.prepare(sql)
            var results: [FileEntry] = []

            for row in try statement.run(ftsQuery, limit) {
                do {
                    let entry = try self.parseFileEntry(from: row)
                    results.append(entry)
                } catch {
                    // Log parsing error but continue processing other rows
                    self.logger.searchError("Failed to parse search result: \(error)")
                }
            }

            return results
        }
    }

    /// Search for files only (no directories)
    func searchFilesOnly(query: String, limit: Int = SeekConfig.Database.defaultSearchLimit) async throws -> [FileEntry] {
        let sanitizedQuery = query.replacingOccurrences(of: "\"", with: "\"\"")
        let ftsQuery = "\(sanitizedQuery)*"

        return try await performRead { db in
            let sql = """
                SELECT f.* FROM file_entries f
                JOIN file_entries_fts fts ON f.rowid = fts.rowid
                WHERE fts.name MATCH ? AND f.is_directory = 0
                ORDER BY LENGTH(f.name), f.name
                LIMIT ?
            """

            let statement = try db.prepare(sql)
            var results: [FileEntry] = []

            for row in try statement.run(ftsQuery, limit) {
                do {
                    let entry = try self.parseFileEntry(from: row)
                    results.append(entry)
                } catch {
                    // Log parsing error but continue processing other rows
                    self.logger.searchError("Failed to parse search result: \(error)")
                }
            }

            return results
        }
    }

    /// Advanced search with multiple criteria
    func advancedSearch(
        query: String? = nil,
        extension: String? = nil,
        isDirectory: Bool? = nil,
        minSize: Int64? = nil,
        maxSize: Int64? = nil,
        limit: Int = SeekConfig.Database.defaultSearchLimit
    ) async throws -> [FileEntry] {
        return try await performRead { db in
            var whereConditions: [String] = []
            var parameters: [Any] = []

            // Build dynamic WHERE clause
            if let query = query, !query.isEmpty {
                let sanitizedQuery = query.replacingOccurrences(of: "\"", with: "\"\"")
                whereConditions.append("f.rowid IN (SELECT rowid FROM file_entries_fts WHERE name MATCH ?)")
                parameters.append("\(sanitizedQuery)*")
            }

            if let ext = `extension` {
                whereConditions.append("f.file_extension = ?")
                parameters.append(ext.lowercased())
            }

            if let isDir = isDirectory {
                whereConditions.append("f.is_directory = ?")
                parameters.append(isDir ? 1 : 0)
            }

            if let min = minSize {
                whereConditions.append("f.size >= ?")
                parameters.append(min)
            }

            if let max = maxSize {
                whereConditions.append("f.size <= ?")
                parameters.append(max)
            }

            let whereClause = whereConditions.isEmpty ? "" : "WHERE \(whereConditions.joined(separator: " AND "))"

            let sql = """
                SELECT * FROM file_entries f
                \(whereClause)
                ORDER BY f.name
                LIMIT ?
            """

            parameters.append(limit)

            var results: [FileEntry] = []

            // Safe parameter binding with error handling
            let statement = try db.prepare(sql)

            do {
                // Execute query with proper parameter binding
                switch parameters.count {
                case 1:
                    guard let param0 = parameters[0] as? Binding else {
                        throw SearchError.invalidParameter("Parameter 0 is not a valid Binding")
                    }
                    for row in try statement.run(param0) {
                        do {
                            let entry = try self.parseFileEntry(from: row)
                            results.append(entry)
                        } catch {
                            // Log parsing error but continue processing other rows
                            self.logger.searchError("Failed to parse file entry: \(error)")
                        }
                    }
                case 2:
                    guard let param0 = parameters[0] as? Binding,
                          let param1 = parameters[1] as? Binding else {
                        throw SearchError.invalidParameter("Parameters 0-1 are not valid Bindings")
                    }
                    for row in try statement.run(param0, param1) {
                        do {
                            let entry = try self.parseFileEntry(from: row)
                            results.append(entry)
                        } catch {
                            self.logger.searchError("Failed to parse file entry: \(error)")
                        }
                    }
                case 3:
                    guard let param0 = parameters[0] as? Binding,
                          let param1 = parameters[1] as? Binding,
                          let param2 = parameters[2] as? Binding else {
                        throw SearchError.invalidParameter("Parameters 0-2 are not valid Bindings")
                    }
                    for row in try statement.run(param0, param1, param2) {
                        do {
                            let entry = try self.parseFileEntry(from: row)
                            results.append(entry)
                        } catch {
                            self.logger.searchError("Failed to parse file entry: \(error)")
                        }
                    }
                case 4:
                    guard let param0 = parameters[0] as? Binding,
                          let param1 = parameters[1] as? Binding,
                          let param2 = parameters[2] as? Binding,
                          let param3 = parameters[3] as? Binding else {
                        throw SearchError.invalidParameter("Parameters 0-3 are not valid Bindings")
                    }
                    for row in try statement.run(param0, param1, param2, param3) {
                        do {
                            let entry = try self.parseFileEntry(from: row)
                            results.append(entry)
                        } catch {
                            self.logger.searchError("Failed to parse file entry: \(error)")
                        }
                    }
                case 5:
                    guard let param0 = parameters[0] as? Binding,
                          let param1 = parameters[1] as? Binding,
                          let param2 = parameters[2] as? Binding,
                          let param3 = parameters[3] as? Binding,
                          let param4 = parameters[4] as? Binding else {
                        throw SearchError.invalidParameter("Parameters 0-4 are not valid Bindings")
                    }
                    for row in try statement.run(param0, param1, param2, param3, param4) {
                        do {
                            let entry = try self.parseFileEntry(from: row)
                            results.append(entry)
                        } catch {
                            self.logger.searchError("Failed to parse file entry: \(error)")
                        }
                    }
                default:
                    for row in try statement.run() {
                        do {
                            let entry = try self.parseFileEntry(from: row)
                            results.append(entry)
                        } catch {
                            self.logger.searchError("Failed to parse file entry: \(error)")
                        }
                    }
                }
            } catch {
                throw SearchError.resultProcessingFailed(error)
            }

            return results
        }
    }

    // MARK: - Helper Methods

    private func parseFileEntry(from row: [Any?]) throws -> FileEntry {
        guard row.count >= 6 else {
            throw SearchError.invalidParameter("Row does not have enough columns: \(row.count)")
        }

        guard let name = row[0] as? String else {
            throw SearchError.invalidParameter("Name column is not a string")
        }

        guard let fullPath = row[1] as? String else {
            throw SearchError.invalidParameter("Full path column is not a string")
        }

        guard let isDirectory = row[2] as? Int64 else {
            throw SearchError.invalidParameter("Is directory column is not an integer")
        }

        guard let dateModified = row[5] as? Double else {
            throw SearchError.invalidParameter("Date modified column is not a number")
        }

        let fileExtension = row[3] as? String
        let size = row[4] as? Int64

        return FileEntry(
            name: name,
            fullPath: fullPath,
            isDirectory: isDirectory != 0,
            fileExtension: fileExtension,
            size: size,
            dateModified: Date(timeIntervalSince1970: dateModified)
        )
    }
}