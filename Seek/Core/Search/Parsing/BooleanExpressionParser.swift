import Foundation

/// Handles parsing of complex boolean expressions with operator precedence
class BooleanExpressionParser {

    private let tokenizer = QueryTokenizer()
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Parse boolean expression tokens into a QueryExpression tree
    /// Handles operator precedence: Parentheses > NOT > AND > OR
    func parseBooleanExpression(_ tokens: [String]) throws -> QueryParser.QueryExpression {
        var index = 0
        return try parseOrExpression(tokens, &index)
    }
    
    // ------------------------------------------
    // MARK: - Expression Parsing with Precedence
    // ------------------------------------------
    
    // Precedence (highest to lowest):
    // 1. Parentheses
    // 2. NOT / !
    // 3. AND (implicit or explicit)
    // 4. OR / |

    private func parseOrExpression(_ tokens: [String], _ index: inout Int) throws -> QueryParser.QueryExpression {
        var expressions: [QueryParser.QueryExpression] = []
        expressions.append(try parseAndExpression(tokens, &index))

        while index < tokens.count && (tokens[index] == "|") {
            index += 1  // consume OR
            expressions.append(try parseAndExpression(tokens, &index))
        }

        return expressions.count == 1 ? expressions[0] : .or(expressions)
    }

    private func parseAndExpression(_ tokens: [String], _ index: inout Int) throws -> QueryParser.QueryExpression {
        var expressions: [QueryParser.QueryExpression] = []
        expressions.append(try parseNotExpression(tokens, &index))

        while index < tokens.count && tokens[index] == "&" {
            index += 1  // consume AND
            expressions.append(try parseNotExpression(tokens, &index))
        }

        return expressions.count == 1 ? expressions[0] : .and(expressions)
    }

    private func parseNotExpression(_ tokens: [String], _ index: inout Int) throws -> QueryParser.QueryExpression {
        guard index < tokens.count else {
            throw QueryError.missingOperand
        }

        if tokens[index] == "!" {
            index += 1  // consume NOT
            return .not(try parsePrimaryExpression(tokens, &index))
        }

        return try parsePrimaryExpression(tokens, &index)
    }

    private func parsePrimaryExpression(_ tokens: [String], _ index: inout Int) throws -> QueryParser.QueryExpression {
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

            // Check if this token is a key-value pair and validate it
            if let (key, value) = tokenizer.parseKeyValue(token) {
                // Try to validate the key-value pair
                let keyValueParser = KeyValueParser()
                do {
                    let _ = try keyValueParser.parseKeyValue(key: key, value: value)
                    return .keyValue(key: key, value: value)
                } catch {
                    // Invalid key-value pair, treat as regular term
                    return .term(token)
                }
            } else {
                return .term(token)
            }
        }
    }
    
    // -----------------------------
    // MARK: - Implicit AND Addition
    // -----------------------------

    /// Add implicit AND operators between consecutive terms
    func addImplicitAND(_ tokens: [String]) -> [String] {
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
    
    // ----------------------
    // MARK: - Helper Methods
    // ----------------------

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
