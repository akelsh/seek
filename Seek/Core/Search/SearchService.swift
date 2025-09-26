import Foundation
import SQLite

class SearchService {
    
    // ------------------
    // MARK: - Properties
    // ------------------
    
    private let databaseService = DatabaseService.shared
    private let queryParser = QueryParser()
    private let logger = LoggingService.shared

    // Search result type
    struct SearchResult {
        let entries: [FileEntry]
        let totalCount: Int
        let searchTime: TimeInterval
    }
    
    // --------------------------
    // MARK: - Main Search Method
    // --------------------------

    func search(query: String, limit: Int = SeekConfig.Database.defaultSearchLimit) async throws -> SearchResult {
        let startTime = Date()

        logger.searchInfo("Search query: '\(query)'")

        // Parse query into expression
        let expression = try queryParser.parse(query)
        logger.searchDebug("Parsed expression")

        // Execute unified search
        let entries = try await searchWithExpression(expression: expression, limit: limit)

        let searchTime = Date().timeIntervalSince(startTime)

        logger.searchInfo("Search completed: found \(entries.count) results in \(String(format: "%.3f", searchTime))s")

        return SearchResult(
            entries: entries,
            totalCount: entries.count,
            searchTime: searchTime
        )
    }

    // -----------------------------
    // MARK: - Unified Search Method
    // -----------------------------

    /// Unified search - handles all query expressions
    private func searchWithExpression(expression: QueryParser.QueryExpression, limit: Int) async throws -> [FileEntry] {
        return try await databaseService.performRead { db in
            let (whereClause, bindValues) = self.buildQuery(expression)

            let sql = 
            """
                SELECT name, full_path, is_directory, file_extension, size, date_modified
                FROM file_entries
                WHERE \(whereClause)
                ORDER BY LENGTH(name), name
                LIMIT ?
            """

            let statement = try db.prepare(sql)

            var finalBindValues = bindValues
            finalBindValues.append(limit)

            var entries: [FileEntry] = []
            for row in try statement.run(finalBindValues) {
                let entry = FileEntry(
                    name: row[0] as! String,
                    fullPath: row[1] as! String,
                    isDirectory: (row[2] as! Int64) != 0,
                    fileExtension: row[3] as? String,
                    size: row[4] as? Int64,
                    dateModified: Date(timeIntervalSince1970: row[5] as! Double)
                )
                entries.append(entry)
            }

            return entries
        }
    }

    private func buildQuery(_ expression: QueryParser.QueryExpression) -> (whereClause: String, bindValues: [Binding?]) {
        switch expression {
        case .term(let term):
            // Handle empty terms
            if term.isEmpty {
                return ("1=1", [])
            }

            // Handle quoted terms (exact match)
            if term.hasPrefix("\"") && term.hasSuffix("\"") {
                let exact = String(term.dropFirst().dropLast())
                return ("name = ? COLLATE NOCASE", [exact])
            }

            // Handle wildcards
            if term.contains("*") || term.contains("?") {
                var pattern = term.replacingOccurrences(of: "*", with: "%")
                pattern = pattern.replacingOccurrences(of: "?", with: "_")
                return ("name LIKE ? COLLATE NOCASE", [pattern])
            }

            // Handle prefix search (terms ending with * from parser)
            if term.hasSuffix("*") {
                let prefix = String(term.dropLast())
                return ("name LIKE ? COLLATE NOCASE", ["\(prefix)%"])
            } else {
                // Substring search for terms without * (implicit AND behavior)
                return ("name LIKE ? COLLATE NOCASE", ["%\(term)%"])
            }

        case .and(let expressions):
            let subQueries = expressions.map { buildQuery($0) }
            let whereClause = subQueries.map { "(\($0.whereClause))" }.joined(separator: " AND ")
            let bindValues = subQueries.flatMap { $0.bindValues }
            return (whereClause, bindValues)

        case .or(let expressions):
            let subQueries = expressions.map { buildQuery($0) }
            let whereClause = subQueries.map { "(\($0.whereClause))" }.joined(separator: " OR ")
            let bindValues = subQueries.flatMap { $0.bindValues }
            return (whereClause, bindValues)

        case .not(let expression):
            let subQuery = buildQuery(expression)
            return ("NOT (\(subQuery.whereClause))", subQuery.bindValues)
        }
    }
}

// -------------------------
// MARK: - Search Statistics
// -------------------------

extension SearchService {

    /// Get search performance statistics
    func getSearchStats() async throws -> (totalFiles: Int, indexSize: Int64) {
        let totalFiles = try await databaseService.getFileCount()

        // Get database file size
        let dbPath = SeekConfig.Database.databasePath
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: dbPath)
        let indexSize = fileAttributes[.size] as? Int64 ?? 0

        return (totalFiles, indexSize)
    }
}
