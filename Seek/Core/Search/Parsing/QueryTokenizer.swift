import Foundation

/// Handles tokenization of query strings into parseable tokens
/// Supports regular terms, quoted strings, operators, parentheses, and key-value pairs
class QueryTokenizer {
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Tokenize a query string into an array of tokens
    /// Supports key-value pairs in the format "key:value"
    func tokenize(_ query: String) throws -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false

        let chars = Array(query)
        var i = 0

        while i < chars.count {
            let char = chars[i]

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
                } else if char == ":" && !current.isEmpty {
                    // Handle key-value pairs - look ahead to get the value
                    let key = current
                    current = ""

                    // Extract the value part
                    i += 1 // skip the ':'
                    var value = ""

                    // Handle quoted values
                    if i < chars.count && chars[i] == "\"" {
                        value.append(chars[i]) // include opening quote
                        i += 1
                        while i < chars.count && chars[i] != "\"" {
                            value.append(chars[i])
                            i += 1
                        }
                        if i < chars.count {
                            value.append(chars[i]) // include closing quote
                        }
                    } else {
                        // Extract unquoted value until space or operator
                        while i < chars.count &&
                              chars[i] != " " &&
                              !"()&|!".contains(chars[i]) {
                            value.append(chars[i])
                            i += 1
                        }
                        i -= 1 // back up one since we'll increment at end of loop
                    }

                    // Create key-value token
                    let keyValueToken = "\(key):\(value)"
                    tokens.append(keyValueToken)
                } else {
                    current.append(char)
                }
            } else {
                // Inside quotes
                current.append(char)
            }

            i += 1
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
    
    // ----------------------
    // MARK: - Helper Methods
    // ----------------------

    /// Check if a token represents a key-value pair
    func isKeyValuePair(_ token: String) -> Bool {
        // More robust check for key-value pairs
        guard token.contains(":") &&
              !token.hasPrefix("\"") &&
              !token.hasSuffix("\"") &&
              !token.contains(" ") else {
            return false
        }

        // Ensure it's not just a colon with nothing else meaningful
        let parts = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }

        let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let value = String(parts[1]).trimmingCharacters(in: .whitespaces)

        // Must have non-empty key and value
        return !key.isEmpty && !value.isEmpty
    }

    /// Extract key and value from a key-value token
    /// Returns (key, value) tuple or nil if not a valid key-value pair
    func parseKeyValue(_ token: String) -> (key: String, value: String)? {
        guard isKeyValuePair(token) else { return nil }

        let parts = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let value = String(parts[1]).trimmingCharacters(in: .whitespaces)

        guard !key.isEmpty && !value.isEmpty else { return nil }

        return (key: key, value: value)
    }
}
