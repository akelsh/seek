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

    /// Calculate the total size of a bundle (app, package, etc.) by recursively summing all contained files
    private static func calculateBundleSize(for url: URL) -> Int64? {
        return safeFileSystemOperation {
            var totalSize: Int64 = 0

            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { (url, error) -> Bool in
                    logger.error("Error enumerating bundle contents at \(url.path): \(error)")
                    return true // Continue enumeration despite errors
                }
            ) else {
                logger.error("Failed to create enumerator for bundle: \(url.path)")
                return 0
            }

            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else {
                    continue
                }

                // Only count file sizes, not directories
                if let isDirectory = resourceValues.isDirectory, !isDirectory,
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }

            return totalSize
        }
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

        // Calculate size based on whether this is a package/bundle or regular file/directory
        let size: Int64?
        if isPackage && isDirectory {
            // For app bundles and packages, calculate total size by summing all contained files
            if let bundleSize = calculateBundleSize(for: url), bundleSize > 0 {
                size = bundleSize
            } else {
                size = nil
            }
        } else {
            // For regular files and directories, use the standard file size
            size = resourceValues.fileSize.map { Int64($0) }
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