import Foundation

/// Handles validation of query tokens and boolean expressions
class QueryValidator {
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Validate boolean expression structure
    func validateBooleanExpression(_ tokens: [String]) throws {
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

    /// Check if a query contains valid boolean operators and structure
    func isValidBooleanQuery(_ query: String) -> Bool {
        // Quick check first - avoid tokenization for most queries
        if !query.contains(where: { "AND OR NOT & | ! ( )".contains($0) }) {
            return false
        }

        do {
            let tokenizer = QueryTokenizer()
            let tokens = try tokenizer.tokenize(query)

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

    /// Validate input query string before processing
    func validateQueryString(_ query: String) throws {
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
    }
    
    // -----------------------
    // MARK: - Private Methods
    // -----------------------

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
