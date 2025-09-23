import Foundation

extension String {
    /// Validates if a string represents a valid file path
    var isValidFilePath: Bool {
        // Basic validation to ensure it's a valid file path string
        return !isEmpty &&
               !contains("\0") &&
               (hasPrefix("/") || hasPrefix("~")) &&
               !hasPrefix("0x") // Avoid hex addresses that might be passed accidentally
    }
}