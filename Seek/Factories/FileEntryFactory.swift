import Foundation

/// Factory for creating FileEntry objects from filesystem URLs
class FileEntryFactory {

    private static let logger = LoggingService.shared

    /// Safely execute filesystem operations with error handling
    private static func safeFileSystemOperation<T>(_ operation: () throws -> T) -> T? {
        do {
            return try operation()
        } catch {
            logger.error("Filesystem error: \(error)")
            return nil
        }
    }

    /// Get file size using the most reliable method
    private static func getFileSize(for url: URL, resourceValues: URLResourceValues) -> Int64? {
        // Method 1: Try the provided resourceValues first (fastest if it works)
        if let fileSize = resourceValues.fileSize {
            return Int64(fileSize)
        }

        // Method 2: FileManager attributes (this has been working 100% of the time)
        if let attributes = safeFileSystemOperation({
            try FileManager.default.attributesOfItem(atPath: url.path)
        }) {
            if let fileSize = attributes[.size] as? NSNumber {
                return fileSize.int64Value
            }
        }

        // Method 3: Direct file URL resourceValues as final fallback
        if let freshResourceValues = safeFileSystemOperation({
            try url.resourceValues(forKeys: [.fileSizeKey])
        }) {
            if let fileSize = freshResourceValues.fileSize {
                return Int64(fileSize)
            }
        }

        return nil
    }


    /// Create a FileEntry from a URL and optional resource values
    static func createFileEntry(for url: URL, resources: URLResourceValues? = nil) -> FileEntry? {
        let resourceValues: URLResourceValues

        if let provided = resources {
            resourceValues = provided
        } else {
            guard let values = safeFileSystemOperation({
                try url.resourceValues(forKeys: Set(SeekConfig.Indexing.resourceKeys))
            }) else {
                return nil
            }
            resourceValues = values
        }

        let name = resourceValues.name ?? url.lastPathComponent
        let isDirectory = resourceValues.isDirectory ?? false
        let isPackage = resourceValues.isPackage ?? false

        // Calculate size - use reliable method for both files and packages
        let size: Int64?
        if isDirectory && !isPackage {
            // Only regular directories (not app bundles) get no size
            size = nil
        } else {
            // For files AND packages (app bundles), use the reliable file size method
            size = getFileSize(for: url, resourceValues: resourceValues)

            if size == nil {
                let fileExtension = url.pathExtension.isEmpty ? "no extension" : url.pathExtension
                let itemType = isPackage ? "package" : "file"
                logger.error("FileEntryFactory: Could not determine size for \(itemType): \(url.path) (extension: \(fileExtension))")
            }
        }

        let fileExtension = isDirectory ? nil : url.pathExtension.isEmpty ? nil : url.pathExtension.lowercased()
        let dateModified = resourceValues.contentModificationDate ?? Date()

        return FileEntry(
            name: name,
            fullPath: url.path,
            isDirectory: isDirectory,
            fileExtension: fileExtension,
            size: size,
            dateModified: dateModified
        )
    }
}