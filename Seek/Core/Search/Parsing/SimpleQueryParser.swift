import Foundation

/// Handles parsing of simple queries without explicit boolean operators
class SimpleQueryParser {

    private let tokenizer = QueryTokenizer()
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Parse simple queries without explicit boolean operators
    /// Handles single terms, multiple terms (implicit AND), quoted strings, wildcards, and key-value pairs
    func parseSimpleQuery(_ tokens: [String]) throws -> QueryParser.QueryExpression {
        if tokens.count == 1 {
            return try parseSingleToken(tokens[0])
        } else {
            // Multiple terms = implicit AND with substring search (Everything behavior)
            let expressions = try tokens.map { token in
                return try parseToken(token)
            }
            return .and(expressions)
        }
    }
    
    // -----------------------
    // MARK: - Private Methods
    // -----------------------

    private func parseSingleToken(_ token: String) throws -> QueryParser.QueryExpression {
        // Check if it's a key-value pair first and validate it
        if let (key, value) = tokenizer.parseKeyValue(token) {
            // Try to validate the key-value pair
            let keyValueParser = KeyValueParser()
            do {
                let _ = try keyValueParser.parseKeyValue(key: key, value: value)
                return .keyValue(key: key, value: value)
            } catch {
                // Invalid key-value pair, fall through to treat as regular term
            }
        }

        // Handle exact match (quoted)
        if token.hasPrefix("\"") && token.hasSuffix("\"") {
            return .term(token) // Keep quotes for exact matching
        }

        // Handle wildcards
        if token.contains("*") || token.contains("?") {
            return .term(token) // Keep wildcards as-is
        }

        // Single term = prefix search (add *)
        return .term(token + "*")
    }

    private func parseToken(_ token: String) throws -> QueryParser.QueryExpression {
        // Check if it's a key-value pair first and validate it
        if let (key, value) = tokenizer.parseKeyValue(token) {
            // Try to validate the key-value pair
            let keyValueParser = KeyValueParser()
            do {
                let _ = try keyValueParser.parseKeyValue(key: key, value: value)
                return .keyValue(key: key, value: value)
            } catch {
                // Invalid key-value pair, fall through to treat as regular term
            }
        }

        // Handle exact match (quoted)
        if token.hasPrefix("\"") && token.hasSuffix("\"") {
            return .term(token) // Exact
        }

        // Handle wildcards
        if token.contains("*") || token.contains("?") {
            return .term(token) // Wildcard
        }

        // Multiple terms: substring search (no * suffix for Everything-style behavior)
        return .term(token)
    }
}
