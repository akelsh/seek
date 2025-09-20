import Foundation

/// Parser for all search queries with Everything-style behavior
class QueryParser {

    // MARK: - Types

    indirect enum QueryExpression {
        case term(String)
        case and([QueryExpression])
        case or([QueryExpression])
        case not(QueryExpression)
    }

    // MARK: - Public Methods

    /// Parse a query string into a query expression
    func parse(_ query: String) -> QueryExpression {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        // Handle empty query
        if trimmed.isEmpty {
            return .term("")
        }

        let tokens = tokenize(trimmed)

        // Check if this has explicit boolean operators
        if hasExplicitOperators(tokens) {
            // Parse as boolean expression with implicit AND
            let tokensWithImplicitAND = addImplicitAND(tokens)
            var index = 0
            return parseOrExpression(tokensWithImplicitAND, &index)
        } else {
            // Handle simple cases without explicit operators
            return parseSimpleQuery(tokens)
        }
    }

    // MARK: - Simple Query Parsing

    /// Parse queries without explicit boolean operators
    private func parseSimpleQuery(_ tokens: [String]) -> QueryExpression {
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

    // MARK: - Validation

    /// Check if a query contains valid boolean operators and structure
    func isValidBooleanQuery(_ query: String) -> Bool {
        // Quick check first - avoid tokenization for most queries
        if !query.contains(where: { "AND OR NOT & | ! ( )".contains($0) }) {
            return false
        }

        let tokens = tokenize(query)

        // Must have explicit operators to be a boolean query
        let hasExplicitOperators = tokens.contains { isOperator($0) || isParenthesis($0) }

        if hasExplicitOperators {
            return isValidTokenSequence(tokens)
        }

        return false
    }

    // MARK: - Implicit AND Addition

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

    // MARK: - Tokenization

    private func tokenize(_ query: String) -> [String] {
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

        // Convert word operators to symbols for case-insensitive parsing
        let normalizedTokens = tokens.filter { !$0.isEmpty }.map { token in
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

    // MARK: - Precedence

    // 1. Parentheses (highest)
    // 2. NOT / !
    // 3. AND (implicit or explicit)
    // 4. OR / | (lowest)

    private func parseOrExpression(_ tokens: [String], _ index: inout Int) -> QueryExpression {
        var expressions: [QueryExpression] = []
        expressions.append(parseAndExpression(tokens, &index))

        while index < tokens.count && (tokens[index] == "|") {
            index += 1  // consume OR
            expressions.append(parseAndExpression(tokens, &index))
        }

        return expressions.count == 1 ? expressions[0] : .or(expressions)
    }

    private func parseAndExpression(_ tokens: [String], _ index: inout Int) -> QueryExpression {
        var expressions: [QueryExpression] = []
        expressions.append(parseNotExpression(tokens, &index))

        while index < tokens.count && tokens[index] == "&" {
            index += 1  // consume AND
            expressions.append(parseNotExpression(tokens, &index))
        }

        return expressions.count == 1 ? expressions[0] : .and(expressions)
    }

    private func parseNotExpression(_ tokens: [String], _ index: inout Int) -> QueryExpression {
        guard index < tokens.count else { return .term("") }

        if tokens[index] == "!" {
            index += 1  // consume NOT
            return .not(parsePrimaryExpression(tokens, &index))
        }

        return parsePrimaryExpression(tokens, &index)
    }

    private func parsePrimaryExpression(_ tokens: [String], _ index: inout Int) -> QueryExpression {
        guard index < tokens.count else { return .term("") }

        let token = tokens[index]

        if token == "(" {
            index += 1  // consume (
            let expr = parseOrExpression(tokens, &index)
            if index < tokens.count && tokens[index] == ")" {
                index += 1  // consume )
            }
            return expr
        } else {
            index += 1
            return .term(token)
        }
    }

    // MARK: - Helper Methods

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