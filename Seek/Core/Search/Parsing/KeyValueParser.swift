import Foundation

/// Handles parsing and validation of key-value pairs in search queries
/// Supports various search keys like size:, type:, modified:, etc.
class KeyValueParser {
    
    // ----------------------
    // MARK: - Supported Keys
    // ----------------------

    /// Keys that can be used in key-value search pairs
    enum SupportedKey: String, CaseIterable {
        case size = "size"
        case type = "type"
        case ext = "ext"
        case modified = "modified"
        case created = "created"
        case name = "name"
        case path = "path"

        var aliases: [String] {
            switch self {
            case .size:
                return ["size", "filesize"]
            case .type:
                return ["type", "filetype"]
            case .ext:
                return ["ext", "extension"]
            case .modified:
                return ["modified", "mod", "datemodified"]
            case .created:
                return ["created", "dateadded"]
            case .name:
                return ["name", "filename"]
            case .path:
                return ["path", "fullpath"]
            }
        }
    }
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Parse and validate a key-value pair
    /// Returns a normalized (key, value) tuple or throws an error if invalid
    func parseKeyValue(key: String, value: String) throws -> (key: SupportedKey, value: String) {
        // Normalize the key (case-insensitive)
        let normalizedKey = key.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedKey.isEmpty else {
            throw QueryError.invalidSyntax("Empty key in key-value pair")
        }

        // Find supported key
        guard let supportedKey = findSupportedKey(normalizedKey) else {
            throw QueryError.invalidSyntax("Unsupported key '\(key)'. Supported keys: \(supportedKeyList())")
        }

        // Validate the value
        let normalizedValue = value.trimmingCharacters(in: .whitespaces)
        guard !normalizedValue.isEmpty else {
            throw QueryError.invalidSyntax("Empty value for key '\(key)'")
        }

        // Validate value format for specific keys
        try validateValue(normalizedValue, for: supportedKey)

        return (key: supportedKey, value: normalizedValue)
    }

    /// Check if a key is supported (case-insensitive)
    func isSupportedKey(_ key: String) -> Bool {
        let normalizedKey = key.lowercased().trimmingCharacters(in: .whitespaces)
        return findSupportedKey(normalizedKey) != nil
    }

    /// Get a list of all supported keys and their aliases
    func getSupportedKeys() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for key in SupportedKey.allCases {
            result[key.rawValue] = key.aliases
        }
        return result
    }
    
    // -----------------------
    // MARK: - Private Methods
    // -----------------------

    private func findSupportedKey(_ normalizedKey: String) -> SupportedKey? {
        return SupportedKey.allCases.first { supportedKey in
            supportedKey.aliases.contains(normalizedKey)
        }
    }

    private func validateValue(_ value: String, for key: SupportedKey) throws {
        switch key {
        case .size:
            try validateSizeValue(value)
        case .type:
            try validateTypeValue(value)
        case .ext:
            try validateExtensionValue(value)
        case .modified, .created:
            try validateDateValue(value)
        case .name, .path:
            // Name and path values are generally flexible, just check for basic validity
            guard !value.contains("\0") else {
                throw QueryError.invalidSyntax("Invalid characters in \(key.rawValue) value")
            }
        }
    }

    private func validateSizeValue(_ value: String) throws {
        // Support formats like: >100MB, <1GB, 50KB, etc.
        let pattern = #"^[><]?\d+(\.\d+)?(B|KB|MB|GB|TB)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            throw QueryError.invalidSyntax("Invalid size format '\(value)'. Use formats like: >100MB, <1GB, 50KB")
        }

        let range = NSRange(location: 0, length: value.utf16.count)

        if regex.firstMatch(in: value, options: [], range: range) == nil {
            throw QueryError.invalidSyntax("Invalid size format '\(value)'. Use formats like: >100MB, <1GB, 50KB")
        }
    }

    private func validateTypeValue(_ value: String) throws {
        // Common file types
        let validTypes = [
            "image", "video", "audio", "document", "text", "code", "archive",
            "executable", "font", "data", "folder", "directory"
        ]

        let lowerValue = value.lowercased()
        if !validTypes.contains(lowerValue) && !value.hasPrefix(".") {
            // Allow specific extensions starting with dot, or suggest common types
            let suggestion = validTypes.joined(separator: ", ")
            throw QueryError.invalidSyntax("Invalid type '\(value)'. Common types: \(suggestion)")
        }
    }

    private func validateExtensionValue(_ value: String) throws {
        // Extension should be alphanumeric, with optional leading dot
        let cleanExt = value.hasPrefix(".") ? String(value.dropFirst()) : value
        guard !cleanExt.isEmpty && cleanExt.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw QueryError.invalidSyntax("Invalid extension '\(value)'. Use format like: pdf, .jpg, txt")
        }
    }

    private func validateDateValue(_ value: String) throws {
        // Support relative dates like: today, yesterday, thisweek, thismonth
        // And absolute dates like: 2024-01-01, >2024-01-01
        let relativeDates = ["today", "yesterday", "thisweek", "lastweek", "thismonth", "lastmonth", "thisyear", "lastyear"]
        let lowerValue = value.lowercased()

        if relativeDates.contains(lowerValue) {
            return // Valid relative date
        }

        // Check for comparison operators with dates
        if value.hasPrefix(">") || value.hasPrefix("<") {
            let dateString = String(value.dropFirst()).trimmingCharacters(in: .whitespaces)
            try validateAbsoluteDate(dateString)
        } else {
            try validateAbsoluteDate(value)
        }
    }

    private func validateAbsoluteDate(_ dateString: String) throws {
        // Simple date format validation (YYYY-MM-DD)
        let pattern = #"^\d{4}-\d{1,2}-\d{1,2}$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw QueryError.invalidSyntax("Invalid date format '\(dateString)'. Use YYYY-MM-DD or relative terms like 'today', 'thisweek'")
        }

        let range = NSRange(location: 0, length: dateString.utf16.count)

        if regex.firstMatch(in: dateString, options: [], range: range) == nil {
            throw QueryError.invalidSyntax("Invalid date format '\(dateString)'. Use YYYY-MM-DD or relative terms like 'today', 'thisweek'")
        }
    }

    private func supportedKeyList() -> String {
        return SupportedKey.allCases.map { $0.rawValue }.joined(separator: ", ")
    }
}
