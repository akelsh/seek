import Foundation

/// Factory for creating FileEntry objects from filesystem URLs
class FileEntryFactory {

    /// Safely execute filesystem operations with error handling
    private static func safeFileSystemOperation<T>(_ operation: () throws -> T) -> T? {
        do {
            return try operation()
        } catch {
            print("Filesystem error: \(error)")
            return nil
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
        let size = resourceValues.fileSize.map { Int64($0) }
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