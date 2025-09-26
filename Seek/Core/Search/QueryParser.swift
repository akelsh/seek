import Foundation

/// Parser for all search queries with Everything-style behavior
/// Orchestrates specialized parsing components for modularity and maintainability
class QueryParser {

    // -------------
    // MARK: - Types
    // -------------

    indirect enum QueryExpression {
        case term(String)
        case keyValue(key: String, value: String)
        case and([QueryExpression])
        case or([QueryExpression])
        case not(QueryExpression)
    }

    // ----------------------
    // MARK: - Dependencies
    // ----------------------

    private let tokenizer = QueryTokenizer()
    private let validator = QueryValidator()
    private let booleanParser = BooleanExpressionParser()
    private let simpleParser = SimpleQueryParser()
    private let keyValueParser = KeyValueParser()

    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Parse a query string into a query expression with validation
    func parse(_ query: String) throws -> QueryExpression {
        // Input validation
        try validator.validateQueryString(query)
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        // Tokenize the query
        let tokens = try tokenizer.tokenize(trimmed)

        // Validate and parse key-value pairs in tokens
        try validateKeyValueTokens(tokens)

        // Check if this has explicit boolean operators
        if hasExplicitOperators(tokens) {
            // Validate boolean expression structure
            try validator.validateBooleanExpression(tokens)

            // Parse as boolean expression with implicit AND
            let tokensWithImplicitAND = booleanParser.addImplicitAND(tokens)
            return try booleanParser.parseBooleanExpression(tokensWithImplicitAND)
        } else {
            // Handle simple cases without explicit operators
            return try simpleParser.parseSimpleQuery(tokens)
        }
    }

    // ------------------
    // MARK: - Validation
    // ------------------

    /// Check if a query contains valid boolean operators and structure
    func isValidBooleanQuery(_ query: String) -> Bool {
        return validator.isValidBooleanQuery(query)
    }
    
    // -----------------------
    // MARK: - Private Methods
    // -----------------------

    /// Validate any key-value pairs in the tokens
    /// If validation fails, the key-value pair will be treated as a regular term
    private func validateKeyValueTokens(_ tokens: [String]) throws {
        // Don't throw errors for invalid key-value pairs
        // Let them be treated as regular search terms
        for token in tokens {
            if tokenizer.isKeyValuePair(token) {
                if let (key, value) = tokenizer.parseKeyValue(token) {
                    // Try to validate the key-value pair, but don't throw if it fails
                    do {
                        let _ = try keyValueParser.parseKeyValue(key: key, value: value)
                    } catch {
                        // Invalid key-value pair will be treated as regular term in parsing
                        continue
                    }
                }
            }
        }
    }

    /// Check if tokens contain explicit boolean operators
    private func hasExplicitOperators(_ tokens: [String]) -> Bool {
        return tokens.contains { isOperator($0) || isParenthesis($0) }
    }

    // ----------------------
    // MARK: - Helper Methods
    // ----------------------

    private func isOperator(_ token: String) -> Bool {
        return ["&", "|", "!"].contains(token)
    }

    private func isParenthesis(_ token: String) -> Bool {
        return token == "(" || token == ")"
    }
}
