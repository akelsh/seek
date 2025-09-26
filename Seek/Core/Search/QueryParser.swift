import Foundation

/// Parser for all search queries with Everything-style behavior
class QueryParser {
    
    // -------------
    // MARK: - Types
    // -------------

    indirect enum QueryExpression {
        case term(String)
        case and([QueryExpression])
        case or([QueryExpression])
        case not(QueryExpression)
    }
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Parse a query string into a query expression with validation
    func parse(_ query: String) throws -> QueryExpression {
        // Input validation
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        // Validate query length
        guard !trimmed.isEmpty else {
            throw QueryError.emptyQuery
        }

        guard trimmed.count <= 1000 else {
            throw QueryError.invalidSyntax("Query is too long (max 1000 characters)")
        }

        // Validate character set (allow alphanumeric, spaces, quotes, operators, parentheses, wildcards)
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
            .union(.symbols)

        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            throw QueryError.invalidSyntax("Query contains invalid characters")
        }

        let tokens = try tokenize(trimmed)

        // Check if this has explicit boolean operators
        if hasExplicitOperators(tokens) {
            // Validate boolean expression structure
            try validateBooleanExpression(tokens)

            // Parse as boolean expression with implicit AND
            let tokensWithImplicitAND = addImplicitAND(tokens)
            var index = 0
            return try parseOrExpression(tokensWithImplicitAND, &index)
        } else {
            // Handle simple cases without explicit operators
            return try parseSimpleQuery(tokens)
        }
    }
    
    // ----------------------------
    // MARK: - Simple Query Parsing
    // ----------------------------

    /// Validate boolean expression structure
    private func validateBooleanExpression(_ tokens: [String]) throws {
        guard !tokens.isEmpty else {
            throw QueryError.emptyQuery
        }

        // Check for balanced parentheses
        var parenCount = 0
        for token in tokens {
            if token == "(" {
                parenCount += 1
            } else if token == ")" {
                parenCount -= 1
                if parenCount < 0 {
                    throw QueryError.unbalancedParentheses
                }
            }
        }

        if parenCount != 0 {
            throw QueryError.unbalancedParentheses
        }

        // Check for valid operator placement
        for (index, token) in tokens.enumerated() {
            if token == "&" || token == "|" {
                // Binary operators must have terms/expressions on both sides
                if index == 0 || index == tokens.count - 1 {
                    throw QueryError.missingOperand
                }

                let prevToken = tokens[index - 1]
                if !isTerm(prevToken) && prevToken != ")" {
                    throw QueryError.missingOperand
                }

                let nextToken = tokens[index + 1]
                if !isTerm(nextToken) && nextToken != "!" && nextToken != "(" {
                    throw QueryError.missingOperand
                }
            } else if token == "!" {
                // NOT operator must have a term/expression after it
                if index == tokens.count - 1 {
                    throw QueryError.missingOperand
                }

                let nextToken = tokens[index + 1]
                if !isTerm(nextToken) && nextToken != "(" {
                    throw QueryError.missingOperand
                }
            }
        }

        // Check complexity - limit nested depth
        let depth = calculateExpressionDepth(tokens)
        if depth > 10 {
            throw QueryError.expressionTooComplex
        }
    }

    private func calculateExpressionDepth(_ tokens: [String]) -> Int {
        var maxDepth = 0
        var currentDepth = 0

        for token in tokens {
            if token == "(" {
                currentDepth += 1
                maxDepth = max(maxDepth, currentDepth)
            } else if token == ")" {
                currentDepth -= 1
            }
        }

        return maxDepth
    }

    /// Parse queries without explicit boolean operators
    private func parseSimpleQuery(_ tokens: [String]) throws -> QueryExpression {
        if tokens.count == 1 {
            let token = tokens[0]

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
        } else {
            // Multiple terms = implicit AND with substring search (Everything behavior)
            let substringTerms = tokens.map { token in
                if token.hasPrefix("\"") && token.hasSuffix("\"") {
                    return QueryExpression.term(token) // Exact
                } else if token.contains("*") || token.contains("?") {
                    return QueryExpression.term(token) // Wildcard
                } else {
                    return QueryExpression.term(token) // Substring (no * suffix)
                }
            }
            return .and(substringTerms)
        }
    }

    /// Check if tokens contain explicit boolean operators
    private func hasExplicitOperators(_ tokens: [String]) -> Bool {
        return tokens.contains { isOperator($0) || isParenthesis($0) }
    }
    
    // ------------------
    // MARK: - Validation
    // ------------------

    /// Check if a query contains valid boolean operators and structure
    func isValidBooleanQuery(_ query: String) -> Bool {
        // Quick check first - avoid tokenization for most queries
        if !query.contains(where: { "AND OR NOT & | ! ( )".contains($0) }) {
            return false
        }

        do {
            let tokens = try tokenize(query)

            // Must have explicit operators to be a boolean query
            let hasExplicitOperators = tokens.contains { isOperator($0) || isParenthesis($0) }

            if hasExplicitOperators {
                return isValidTokenSequence(tokens)
            }

            return false
        } catch {
            // If tokenization fails, it's not a valid boolean query
            return false
        }
    }
    
    // -----------------------------
    // MARK: - Implicit AND Addition
    // -----------------------------

    private func addImplicitAND(_ tokens: [String]) -> [String] {
        guard tokens.count > 1 else { return tokens }

        var result: [String] = []

        for i in 0..<tokens.count {
            result.append(tokens[i])

            // Add implicit AND between consecutive terms
            if i < tokens.count - 1 {
                let current = tokens[i]
                let next = tokens[i + 1]

                // Add AND between two terms (not operators or parentheses)
                let shouldAddAND = isTerm(current) && isTerm(next) &&
                                  current != ")" && next != "(" &&
                                  !isOperator(current)

                // Also add AND after closing paren before term
                let afterCloseParen = current == ")" && isTerm(next)

                // Also add AND between term and opening paren
                let beforeOpenParen = isTerm(current) && next == "("

                let beforeNOT = isTerm(current) && next == "!"

                if shouldAddAND || afterCloseParen || beforeOpenParen || beforeNOT {
                    result.append("&")
                }
            }
        }

        return result
    }
    
    // --------------------
    // MARK: - Tokenization
    // --------------------

    private func tokenize(_ query: String) throws -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false

        for char in query {
            if char == "\"" {
                // Handle quotes - keep them as part of the term
                if inQuotes {
                    // Closing quote - add the complete quoted term
                    current.append(char)
                    tokens.append(current)
                    current = ""
                    inQuotes = false
                } else {
                    // Opening quote - start quoted term
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                    current.append(char)
                    inQuotes = true
                }
            } else if !inQuotes {
                // Handle operators and special characters
                if char == " " {
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                } else if "()".contains(char) {
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                    tokens.append(String(char))
                } else if char == "&" {
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                    tokens.append("&")
                } else if char == "|" {
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                    tokens.append("|")
                } else if char == "!" {
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                    tokens.append("!")
                } else {
                    current.append(char)
                }
            } else {
                // Inside quotes
                current.append(char)
            }
        }

        // Add final token
        if !current.isEmpty {
            tokens.append(current)
        }

        // Check for unclosed quotes
        if inQuotes {
            throw QueryError.invalidSyntax("Unclosed quotes in query")
        }

        // Filter empty tokens and validate
        let filteredTokens = tokens.filter { !$0.isEmpty }

        guard !filteredTokens.isEmpty else {
            throw QueryError.tokenizationFailed("No valid tokens found")
        }

        // Convert word operators to symbols for case-insensitive parsing
        let normalizedTokens = filteredTokens.map { token in
            let lowerToken = token.lowercased()
            switch lowerToken {
            case "and":
                return "&"
            case "or":
                return "|"
            case "not":
                return "!"
            default:
                return token
            }
        }

        return normalizedTokens
    }
    
    // ------------------
    // MARK: - Precedence
    // ------------------

    // 1. Parentheses (highest)
    // 2. NOT / !
    // 3. AND (implicit or explicit)
    // 4. OR / | (lowest)

    private func parseOrExpression(_ tokens: [String], _ index: inout Int) throws -> QueryExpression {
        var expressions: [QueryExpression] = []
        expressions.append(try parseAndExpression(tokens, &index))

        while index < tokens.count && (tokens[index] == "|") {
            index += 1  // consume OR
            expressions.append(try parseAndExpression(tokens, &index))
        }

        return expressions.count == 1 ? expressions[0] : .or(expressions)
    }

    private func parseAndExpression(_ tokens: [String], _ index: inout Int) throws -> QueryExpression {
        var expressions: [QueryExpression] = []
        expressions.append(try parseNotExpression(tokens, &index))

        while index < tokens.count && tokens[index] == "&" {
            index += 1  // consume AND
            expressions.append(try parseNotExpression(tokens, &index))
        }

        return expressions.count == 1 ? expressions[0] : .and(expressions)
    }

    private func parseNotExpression(_ tokens: [String], _ index: inout Int) throws -> QueryExpression {
        guard index < tokens.count else {
            throw QueryError.missingOperand
        }

        if tokens[index] == "!" {
            index += 1  // consume NOT
            return .not(try parsePrimaryExpression(tokens, &index))
        }

        return try parsePrimaryExpression(tokens, &index)
    }

    private func parsePrimaryExpression(_ tokens: [String], _ index: inout Int) throws -> QueryExpression {
        guard index < tokens.count else {
            throw QueryError.missingOperand
        }

        let token = tokens[index]

        if token == "(" {
            index += 1  // consume (
            let expr = try parseOrExpression(tokens, &index)
            guard index < tokens.count && tokens[index] == ")" else {
                throw QueryError.unbalancedParentheses
            }
            index += 1  // consume )
            return expr
        } else {
            index += 1
            return .term(token)
        }
    }
    
    // ----------------------
    // MARK: - Helper Methods
    // ----------------------

    private func isValidTokenSequence(_ tokens: [String]) -> Bool {
        // Check for balanced parentheses
        var parenCount = 0
        for token in tokens {
            if token == "(" {
                parenCount += 1
            } else if token == ")" {
                parenCount -= 1
                if parenCount < 0 { return false } // More closing than opening
            }
        }
        if parenCount != 0 { return false } // Unbalanced parentheses

        // Check for valid operator placement
        for (index, token) in tokens.enumerated() {
            if token == "&" || token == "|" {
                // Binary operators must have terms/expressions on both sides
                if index == 0 || index == tokens.count - 1 {
                    return false
                }
                // Previous token should be a term or closing paren
                let prevToken = tokens[index - 1]
                if !isTerm(prevToken) && prevToken != ")" {
                    return false
                }
                // Next token should be a term, NOT, or opening paren
                let nextToken = tokens[index + 1]
                if !isTerm(nextToken) && nextToken != "!" && nextToken != "(" {
                    return false
                }
            } else if token == "!" {
                // Unary operators must have a term/expression after them
                if index == tokens.count - 1 {
                    return false
                }
                // Next token should be a term or opening paren
                let nextToken = tokens[index + 1]
                if !isTerm(nextToken) && nextToken != "(" {
                    return false
                }
            }
        }

        return true
    }

    private func isOperator(_ token: String) -> Bool {
        return ["&", "|", "!"].contains(token)
    }

    private func isParenthesis(_ token: String) -> Bool {
        return token == "(" || token == ")"
    }

    private func isTerm(_ token: String) -> Bool {
        return !isOperator(token) && !isParenthesis(token)
    }
}
