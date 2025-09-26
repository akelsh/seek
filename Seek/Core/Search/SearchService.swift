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

        case .keyValue(key: let key, value: let value):
            return buildKeyValueQuery(key: key, value: value)
        }
    }

    /// Build SQL query for key-value pairs
    private func buildKeyValueQuery(key: String, value: String) -> (whereClause: String, bindValues: [Binding?]) {
        // Safety check - if key or value is empty, treat as regular term search
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty &&
              !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ("name LIKE ? COLLATE NOCASE", ["%\(key):\(value)%"])
        }

        let normalizedKey = key.lowercased()

        switch normalizedKey {
        case "name", "filename":
            // Handle name searches
            if value.contains("*") || value.contains("?") {
                var pattern = value.replacingOccurrences(of: "*", with: "%")
                pattern = pattern.replacingOccurrences(of: "?", with: "_")
                return ("name LIKE ? COLLATE NOCASE", [pattern])
            } else {
                return ("name LIKE ? COLLATE NOCASE", ["%\(value)%"])
            }

        case "path", "fullpath":
            // Handle path searches
            if value.contains("*") || value.contains("?") {
                var pattern = value.replacingOccurrences(of: "*", with: "%")
                pattern = pattern.replacingOccurrences(of: "?", with: "_")
                return ("full_path LIKE ? COLLATE NOCASE", [pattern])
            } else {
                return ("full_path LIKE ? COLLATE NOCASE", ["%\(value)%"])
            }

        case "ext", "extension":
            // Handle extension searches
            let cleanExt = value.hasPrefix(".") ? String(value.dropFirst()) : value
            return ("file_extension = ? COLLATE NOCASE", [cleanExt])

        case "size", "filesize":
            // Handle size searches (>100MB, <1GB, etc.)
            return buildSizeQuery(value)

        case "type", "filetype":
            // Handle type searches (image, video, document, etc.)
            return buildTypeQuery(value)

        case "modified", "mod", "datemodified":
            // Handle modified date searches
            return buildDateQuery(value, column: "date_modified")

        case "created", "dateadded":
            // Handle created date searches
            return buildDateQuery(value, column: "date_modified") // Note: we only have date_modified in schema

        default:
            // Unsupported key - fallback to name search
            return ("name LIKE ? COLLATE NOCASE", ["%\(value)%"])
        }
    }

    /// Build size comparison query
    private func buildSizeQuery(_ value: String) -> (whereClause: String, bindValues: [Binding?]) {
        // Parse size values like: >100MB, <1GB, 50KB
        guard let sizeRegex = try? NSRegularExpression(pattern: "^([><]?)(\\d+(?:\\.\\d+)?)(B|KB|MB|GB|TB)?$", options: .caseInsensitive) else {
            // Regex compilation failed, fallback to name search
            return ("name LIKE ? COLLATE NOCASE", ["%\(value)%"])
        }

        let range = NSRange(location: 0, length: value.utf16.count)

        guard let match = sizeRegex.firstMatch(in: value, options: [], range: range) else {
            // Invalid format, fallback to name search
            return ("name LIKE ? COLLATE NOCASE", ["%\(value)%"])
        }

        // Safely extract components
        let comparisonOp: String = {
            let range1 = match.range(at: 1)
            if range1.location != NSNotFound, let swiftRange = Range(range1, in: value) {
                return String(value[swiftRange])
            }
            return "="
        }()

        let numberStr: String = {
            let range2 = match.range(at: 2)
            if range2.location != NSNotFound, let swiftRange = Range(range2, in: value) {
                return String(value[swiftRange])
            }
            return "0"
        }()

        let unit: String = {
            let range3 = match.range(at: 3)
            if range3.location != NSNotFound, let swiftRange = Range(range3, in: value) {
                return String(value[swiftRange])
            }
            return "B"
        }()

        guard let number = Double(numberStr) else {
            // Invalid number, fallback to name search
            return ("name LIKE ? COLLATE NOCASE", ["%\(value)%"])
        }

        // Convert to bytes
        let multiplier: Double = {
            switch unit.uppercased() {
            case "B": return 1
            case "KB": return 1024
            case "MB": return 1024 * 1024
            case "GB": return 1024 * 1024 * 1024
            case "TB": return 1024 * 1024 * 1024 * 1024
            default: return 1
            }
        }()

        let bytes = Int64(number * multiplier)
        let sqlOperator = comparisonOp.isEmpty ? "=" : comparisonOp

        return ("size \(sqlOperator) ?", [bytes])
    }

    /// Build type query based on file type categories
    private func buildTypeQuery(_ value: String) -> (whereClause: String, bindValues: [Binding?]) {
        let lowerValue = value.lowercased()

        switch lowerValue {
        case "image":
            let imageExts = [
              // Common Web Formats
              "jpg", "jpeg", "png", "gif", "webp", "avif", "svg",
              
              // Traditional Formats
              "bmp", "tiff", "tif", "ico", "cur",
              
              // Professional/Raw Formats
              "raw", "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "pef", "srw", "raf", "3fr", "fff", "dcr", "kdc", "srf", "mrw", "x3f",
              
              // Adobe Formats
              "psd", "psb", "ai", "eps", "pdf",
              
              // Other Graphics Software
              "xcf", "gimp", "kra", "ora", "clip", "sai", "mdp", "pdn",
              
              // Apple Formats
              "heic", "heif", "heix",
              
              // Legacy/Specialized
              "pcx", "tga", "dds", "exr", "hdr", "pic", "pict", "sgi", "iff", "lbm", "pbm", "pgm", "ppm", "pnm", "xbm", "xpm",
              
              // Animation
              "apng", "flif",
              
              // Medical/Scientific
              "dcm", "dicom", "fits", "fit",
              
              // Game/3D
              "vtf", "tex", "ktx", "astc"
            ];
            let placeholders = imageExts.map { _ in "?" }.joined(separator: ", ")
            return ("file_extension IN (\(placeholders)) COLLATE NOCASE", imageExts.map { $0 as Binding? })

        case "video":
            let videoExts = [
              // Modern/Web Standard Formats
              "mp4", "webm", "mkv", "avi", "mov", "m4v",
              
              // Windows/Microsoft
              "wmv", "asf", "wma",
              
              // Streaming/Web
              "flv", "f4v", "m3u8", "ts", "m2ts", "mts",
              
              // Apple/iOS
              "mov", "qt", "m4v", "3gp", "3g2",
              
              // Professional/Broadcasting
              "mxf", "prores", "dnxhd", "r3d", "braw", "arri", "dpx", "exr",
              
              // Legacy Formats
              "mpg", "mpeg", "m2v", "vob", "dat", "rm", "rmvb", "ogv", "ogg",
              
              // High Definition
              "m2ts", "mts", "avchd", "bdmv",
              
              // Compression Standards
              "h264", "h265", "hevc", "vp8", "vp9", "av1",
              
              // Animation/Graphics
              "gif", "apng", "swf", "fla",
              
              // Raw/Uncompressed
              "yuv", "y4m", "nut",
              
              // Audio-Visual Container
              "mkv", "mka", "divx", "xvid",
              
              // Specialized/Professional
              "bik", "roq", "smk", "ivf", "drc", "lrv", "thm"
            ];
            let placeholders = videoExts.map { _ in "?" }.joined(separator: ", ")
            return ("file_extension IN (\(placeholders)) COLLATE NOCASE", videoExts.map { $0 as Binding? })

        case "audio":
            let audioExts = [
              // Common Compressed Formats
              "mp3", "aac", "m4a", "ogg", "oga", "wma",
              
              // Lossless Formats
              "flac", "wav", "aiff", "aif", "aifc", "alac", "ape", "wv", "tta", "tak",
              
              // Apple Formats
              "m4a", "m4b", "m4p", "m4r", "caf", "alac",
              
              // Professional/Studio
              "wav", "aiff", "bwf", "rf64", "w64", "au", "snd",
              
              // Open Source/Web
              "ogg", "oga", "opus", "spx", "webm",
              
              // Microsoft/Windows
              "wma", "wax", "wmv", "asf",
              
              // Legacy/Specialized
              "ra", "ram", "rm", "ac3", "dts", "dtshd", "eac3", "mka", "mpc", "mp+", "mpp",
              
              // Raw/Uncompressed
              "pcm", "raw", "s16", "s24", "s32", "f32", "f64",
              
              // Tracker/Module Music
              "mod", "it", "s3m", "xm", "umx", "mo3",
              
              // Game Audio
              "vag", "at3", "at9", "adx", "hca", "acb", "awb", "fsb", "wem", "bnk",
              
              // Mobile/Phone
              "3gp", "amr", "awb", "qcp",
              
              // Streaming/Adaptive
              "m3u", "m3u8", "pls", "xspf", "asx", "ram",
              
              // MIDI/Synthesis
              "mid", "midi", "kar", "rmi", "smf",
              
              // Voice/Speech
              "vox", "gsm", "speex", "silk"
            ];
            let placeholders = audioExts.map { _ in "?" }.joined(separator: ", ")
            return ("file_extension IN (\(placeholders)) COLLATE NOCASE", audioExts.map { $0 as Binding? })

        case "document":
            let docExts = [
              // PDF
              "pdf", "xps", "oxps",
              
              // Microsoft Word
              "doc", "docx", "docm", "dot", "dotx", "dotm",
              
              // Plain Text
              "txt", "text", "asc", "log", "readme",
              
              // Rich Text
              "rtf", "rtfd",
              
              // OpenDocument (LibreOffice/OpenOffice)
              "odt", "ott", "odm", "oth",
              
              // Apple
              "pages", "numbers", "key",
              
              // Microsoft Excel
              "xls", "xlsx", "xlsm", "xlsb", "xlt", "xltx", "xltm", "csv", "tsv",
              
              // Microsoft PowerPoint
              "ppt", "pptx", "pptm", "pot", "potx", "potm", "pps", "ppsx", "ppsm",
              
              // OpenDocument Spreadsheets & Presentations
              "ods", "ots", "odp", "otp", "odg", "otg", "odb", "odf",
              
              // Google Workspace (when downloaded)
              "gdoc", "gsheet", "gslides",
              
              // Legacy Word Processors
              "wpd", "wp", "wp6", "wp5", "wps", "lwp", "sam", "wri",
              
              // eBooks
              "epub", "mobi", "azw", "azw3", "fb2", "lit", "pdb", "prc", "lrf", "rb", "tcr",
              
              // LaTeX/Academic
              "tex", "latex", "bib", "cls", "sty", "aux", "dvi", "ps", "eps",
              
              // Markdown & Markup
              "md", "markdown", "mdown", "mkd", "rst", "org", "textile", "wiki",
              
              // Publishing
              "indd", "qxd", "pub", "scriv", "scrivx", "fm", "mif",
              
              // Archive Formats (document-related)
              "zip", "rar", "7z", "tar", "gz", "bz2", "xz",
              
              // Web Documents
              "html", "htm", "mhtml", "mht", "xhtml", "xml", "xsl", "xslt",
              
              // Fonts (document-related)
              "ttf", "otf", "woff", "woff2", "eot",
              
              // Scientific/Data
              "bib", "ris", "enw", "nbib", "medline", "ovid"
            ];
            let placeholders = docExts.map { _ in "?" }.joined(separator: ", ")
            return ("file_extension IN (\(placeholders)) COLLATE NOCASE", docExts.map { $0 as Binding? })

        case "code":
            let codeExts = [
              // JavaScript/TypeScript
              "js", "jsx", "ts", "tsx", "mjs", "cjs",
              
              // Python
              "py", "pyi", "pyw",
              
              // Java/JVM Languages
              "java", "kt", "kts", "scala", "groovy",
              
              // C/C++
              "c", "cpp", "cxx", "cc", "c++", "h", "hpp", "hxx", "hh", "h++",
              
              // C#/.NET
              "cs", "vb", "fs", "fsx",
              
              // Web Development
              "html", "htm", "css", "scss", "sass", "less", "php", "vue", "svelte",
              
              // Mobile Development
              "swift", "dart", "m", "mm",
              
              // System Programming
              "rs", "go", "zig",
              
              // Ruby
              "rb", "rbw", "rake", "ru",
              
              // Perl
              "pl", "pm", "pod",
              
              // Shell Scripting
              "sh", "bash", "zsh", "fish", "ps1",
              
              // R & Data Science
              "r", "R", "rmd", "Rmd",
              
              // Other Popular Languages
              "lua", "julia", "jl", "clj", "cljs", "hs", "elm", "ml", "ocaml",
              "d", "nim", "crystal", "cr", "v",
              
              // SQL
              "sql",
              
              // Assembly
              "asm", "s",
              
              // Config/Data (commonly edited by developers)
              "json", "yaml", "yml", "toml", "xml"
            ];
            let placeholders = codeExts.map { _ in "?" }.joined(separator: ", ")
            return ("file_extension IN (\(placeholders)) COLLATE NOCASE", codeExts.map { $0 as Binding? })

        case "archive":
            let archiveExts = [
              // Common Cross-platform
              "zip", "rar", "7z", "tar", "gz", "bz2", "xz",
              
              // Compound tar formats
              "tar.gz", "tgz", "tar.bz2", "tbz", "tbz2", "tar.xz", "txz", "tar.lz", "tar.lzma", "tar.z",
              
              // Windows-specific
              "cab", "msi", "exe", "ace", "arj", "lzh", "lha",
              
              // Unix/Linux
              "Z", "compress", "cpio", "shar", "ar", "deb", "rpm", "pkg",
              
              // Apple/macOS
              "dmg", "pkg", "sit", "sitx", "hqx", "bin", "sea",
              
              // Advanced/Modern
              "zst", "zstd", "lz4", "lzo", "snappy", "brotli", "br",
              
              // ISO/Disc Images
              "iso", "img", "bin", "cue", "nrg", "mdf", "mds", "ccd", "sub",
              
              // Specialized
              "war", "jar", "ear", "aar", "apk", "ipa", "xpi", "crx",
              
              // Backup/Proprietary
              "bak", "backup", "pea", "uha", "zpaq", "arc", "pak", "lzx",
              
              // Game Archives
              "pk3", "pk4", "wad", "vpk", "gcf", "ncf", "bsp", "res",
              
              // Legacy/Rare
              "zoo", "ice", "hyp", "sqz", "pit", "now", "yz1", "ha",
              
              // Self-extracting
              "sfx", "sea", "run"
            ];
            let placeholders = archiveExts.map { _ in "?" }.joined(separator: ", ")
            return ("file_extension IN (\(placeholders)) COLLATE NOCASE", archiveExts.map { $0 as Binding? })

        case "folder", "directory":
            return ("is_directory = ?", [1])

        default:
            // Treat as a specific extension
            let cleanExt = value.hasPrefix(".") ? String(value.dropFirst()) : value
            return ("file_extension = ? COLLATE NOCASE", [cleanExt])
        }
    }

    /// Build date query for modified/created dates
    private func buildDateQuery(_ value: String, column: String) -> (whereClause: String, bindValues: [Binding?]) {
        let lowerValue = value.lowercased()
        let now = Date()
        let calendar = Calendar.current

        // Handle relative dates
        let targetDate: Date? = {
            switch lowerValue {
            case "today":
                return calendar.startOfDay(for: now)
            case "yesterday":
                return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
            case "thisweek":
                return calendar.dateInterval(of: .weekOfYear, for: now)?.start
            case "lastweek":
                let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
                return calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.start
            case "thismonth":
                return calendar.dateInterval(of: .month, for: now)?.start
            case "lastmonth":
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
                return calendar.dateInterval(of: .month, for: lastMonth)?.start
            case "thisyear":
                return calendar.dateInterval(of: .year, for: now)?.start
            case "lastyear":
                let lastYear = calendar.date(byAdding: .year, value: -1, to: now)!
                return calendar.dateInterval(of: .year, for: lastYear)?.start
            default:
                return nil
            }
        }()

        if let date = targetDate {
            let timestamp = date.timeIntervalSince1970
            return ("\(column) >= ?", [timestamp])
        }

        // Handle absolute dates with comparison operators
        if value.hasPrefix(">") || value.hasPrefix("<") {
            let comparisonOp = value.hasPrefix(">") ? ">" : "<"
            let dateString = String(value.dropFirst()).trimmingCharacters(in: .whitespaces)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            if let date = formatter.date(from: dateString) {
                let timestamp = date.timeIntervalSince1970
                return ("\(column) \(comparisonOp) ?", [timestamp])
            }
        } else {
            // Try parsing as absolute date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            if let date = formatter.date(from: value) {
                let timestamp = date.timeIntervalSince1970
                let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
                let nextDayTimestamp = nextDay.timeIntervalSince1970
                return ("\(column) >= ? AND \(column) < ?", [timestamp, nextDayTimestamp])
            }
        }

        // Fallback: no match
        return ("1=0", [])
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
