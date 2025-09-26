import Foundation
import CoreServices

/// Comprehensive error hierarchy for the Seek application
enum SeekError: Error, LocalizedError {
    case database(DatabaseError)
    case fileSystem(FileSystemError)
    case search(SearchError)
    case indexing(IndexingError)
    case query(QueryError)
    case configuration(ConfigurationError)

    var errorDescription: String? {
        switch self {
        case .database(let error):
            return "Database Error: \(error.localizedDescription)"
        case .fileSystem(let error):
            return "File System Error: \(error.localizedDescription)"
        case .search(let error):
            return "Search Error: \(error.localizedDescription)"
        case .indexing(let error):
            return "Indexing Error: \(error.localizedDescription)"
        case .query(let error):
            return "Query Error: \(error.localizedDescription)"
        case .configuration(let error):
            return "Configuration Error: \(error.localizedDescription)"
        }
    }
}

/// Database-specific errors
enum DatabaseError: Error, LocalizedError {
    case directoryCreationFailed(String)
    case connectionSetupFailed(Error)
    case tableCreationFailed(Error)
    case connectionUnavailable
    case queryExecutionFailed(String, Error)
    case invalidData(String)
    case transactionFailed(Error)
    case backupFailed(Error)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path):
            return "Failed to create database directory at: \(path)"
        case .connectionSetupFailed(let error):
            return "Failed to setup database connection: \(error.localizedDescription)"
        case .tableCreationFailed(let error):
            return "Failed to create database tables: \(error.localizedDescription)"
        case .connectionUnavailable:
            return "Database connection is not available"
        case .queryExecutionFailed(let query, let error):
            return "Failed to execute query '\(query)': \(error.localizedDescription)"
        case .invalidData(let description):
            return "Invalid database data: \(description)"
        case .transactionFailed(let error):
            return "Database transaction failed: \(error.localizedDescription)"
        case .backupFailed(let error):
            return "Database backup failed: \(error.localizedDescription)"
        }
    }
}

/// File system monitoring errors
enum FileSystemError: Error, LocalizedError {
    case streamCreationFailed
    case streamStartFailed
    case pathAccessDenied(String)
    case invalidPath(String)
    case exclusionServiceUnavailable
    case batchProcessingFailed(Error)
    case eventProcessingFailed(FSEventStreamEventFlags, String)

    var errorDescription: String? {
        switch self {
        case .streamCreationFailed:
            return "Failed to create file system event stream"
        case .streamStartFailed:
            return "Failed to start file system event stream"
        case .pathAccessDenied(let path):
            return "Access denied for path: \(path)"
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
        case .exclusionServiceUnavailable:
            return "File exclusion service is not available"
        case .batchProcessingFailed(let error):
            return "Failed to process file system changes: \(error.localizedDescription)"
        case .eventProcessingFailed(let flags, let path):
            return "Failed to process file system event (flags: \(flags)) for path: \(path)"
        }
    }
}

/// Search operation errors
enum SearchError: Error, LocalizedError {
    case invalidQuery(String)
    case queryTooShort
    case queryTooLong
    case invalidParameter(String)
    case resultProcessingFailed(Error)
    case serviceUnavailable
    case limitExceeded(Int)

    var errorDescription: String? {
        switch self {
        case .invalidQuery(let query):
            return "Invalid search query: \(query)"
        case .queryTooShort:
            return "Search query is too short"
        case .queryTooLong:
            return "Search query is too long"
        case .invalidParameter(let parameter):
            return "Invalid search parameter: \(parameter)"
        case .resultProcessingFailed(let error):
            return "Failed to process search results: \(error.localizedDescription)"
        case .serviceUnavailable:
            return "Search service is currently unavailable"
        case .limitExceeded(let limit):
            return "Search result limit exceeded: \(limit)"
        }
    }
}

/// Indexing operation errors
enum IndexingError: Error, LocalizedError {
    case pathNotFound(String)
    case scannerCreationFailed
    case resourceEnumerationFailed(URL, Error)
    case batchInsertFailed(Error)
    case statisticsUpdateFailed(Error)
    case concurrencyLimitExceeded(Int)
    case memoryPressure

    var errorDescription: String? {
        switch self {
        case .pathNotFound(let path):
            return "Indexing path not found: \(path)"
        case .scannerCreationFailed:
            return "Failed to create file system scanner"
        case .resourceEnumerationFailed(let url, let error):
            return "Failed to enumerate resources at \(url.path): \(error.localizedDescription)"
        case .batchInsertFailed(let error):
            return "Failed to insert batch data: \(error.localizedDescription)"
        case .statisticsUpdateFailed(let error):
            return "Failed to update indexing statistics: \(error.localizedDescription)"
        case .concurrencyLimitExceeded(let limit):
            return "Concurrency limit exceeded: \(limit)"
        case .memoryPressure:
            return "Indexing paused due to memory pressure"
        }
    }
}

/// Query parsing errors
enum QueryError: Error, LocalizedError {
    case emptyQuery
    case invalidSyntax(String)
    case unbalancedParentheses
    case invalidOperator(String)
    case missingOperand
    case tokenizationFailed(String)
    case expressionTooComplex

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Query cannot be empty"
        case .invalidSyntax(let details):
            return "Invalid query syntax: \(details)"
        case .unbalancedParentheses:
            return "Unbalanced parentheses in query"
        case .invalidOperator(let op):
            return "Invalid operator: \(op)"
        case .missingOperand:
            return "Missing operand in query"
        case .tokenizationFailed(let query):
            return "Failed to tokenize query: \(query)"
        case .expressionTooComplex:
            return "Query expression is too complex"
        }
    }
}

/// Configuration errors
enum ConfigurationError: Error, LocalizedError {
    case missingRequiredValue(String)
    case invalidValue(String, String)
    case pathNotAccessible(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredValue(let key):
            return "Missing required configuration value: \(key)"
        case .invalidValue(let key, let value):
            return "Invalid configuration value for \(key): \(value)"
        case .pathNotAccessible(let path):
            return "Configuration path not accessible: \(path)"
        case .permissionDenied(let resource):
            return "Permission denied for configuration resource: \(resource)"
        }
    }
}