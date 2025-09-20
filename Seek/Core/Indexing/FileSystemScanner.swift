import Foundation

/// Handles filesystem scanning and directory traversal operations
class FileSystemScanner {

    /// Safely execute filesystem operations with error handling
    private static func safeFileSystemOperation<T>(_ operation: () throws -> T) -> T? {
        do {
            return try operation()
        } catch {
            print("Filesystem error: \(error)")
            return nil
        }
    }

    /// Get FileManager enumeration options based on configuration
    static func getEnumerationOptions() -> FileManager.DirectoryEnumerationOptions {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if SeekConfig.Indexing.FileExclusion.excludeHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }
        return options
    }

    /// Scan only root-level files (non-recursive) at the given URL
    static func scanRootLevelFiles(at rootURL: URL) -> [FileEntry] {
        var entries: [FileEntry] = []

        let options = getEnumerationOptions()

        guard let contents = safeFileSystemOperation({
            try FileManager.default.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: SeekConfig.Indexing.resourceKeys,
                options: options
            )
        }) else {
            return entries
        }

        // Only process direct files in root (not directories)
        for url in contents {
            guard let resources = safeFileSystemOperation({
                try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            }) else {
                continue
            }

            // Skip symlinks
            if resources.isSymbolicLink == true {
                continue
            }

            // Skip directories - we'll handle them separately
            if resources.isDirectory == true {
                continue
            }

            // Check exclusions for files
            if FileExclusionService.shared.shouldExclude(url: url, isDirectory: false) {
                continue
            }

            // Create and add the file entry
            if let entry = FileEntryFactory.createFileEntry(for: url) {
                entries.append(entry)
            }
        }

        return entries
    }

    /// Get all top-level directories at the given root URL
    static func getTopLevelDirectories(at rootURL: URL) -> [URL] {
        var directories: [URL] = []

        let options = getEnumerationOptions()

        guard let contents = safeFileSystemOperation({
            try FileManager.default.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: options
            )
        }) else {
            return directories
        }

        // Only add actual directories (not packages)
        for url in contents {
            guard let resources = safeFileSystemOperation({
                try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            }) else {
                continue
            }

            // Only add if it's a directory AND not a package
            if resources.isDirectory == true && resources.isPackage != true {
                // Check if excluded
                if !FileExclusionService.shared.shouldExclude(url: url, isDirectory: true) {
                    directories.append(url)
                }
            }
        }

        return directories
    }

    /// Recursively scan a directory and return all file entries
    static func scanDirectoryRecursively(_ directoryURL: URL) async -> [FileEntry] {
        var allEntries: [FileEntry] = []

        guard let resources = safeFileSystemOperation({
            try directoryURL.resourceValues(forKeys: [.isDirectoryKey])
        }), resources.isDirectory == true else {
            return allEntries
        }

        // Add the directory itself
        if let dirEntry = FileEntryFactory.createFileEntry(for: directoryURL) {
            allEntries.append(dirEntry)
        }

        // Get directory contents
        let options = getEnumerationOptions()

        guard let contents = safeFileSystemOperation({
            try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: SeekConfig.Indexing.resourceKeys + [.isPackageKey],
                options: options
            )
        }) else {
            return allEntries
        }

        // Process each item in the directory
        for url in contents {
            guard let itemResources = safeFileSystemOperation({
                try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey])
            }) else {
                continue
            }

            // Skip symlinks
            if itemResources.isSymbolicLink == true {
                continue
            }

            // Check exclusions
            if FileExclusionService.shared.shouldExclude(url: url, isDirectory: itemResources.isDirectory ?? false) {
                continue
            }

            // Handle packages as files
            if itemResources.isPackage == true {
                if let entry = FileEntryFactory.createFileEntry(for: url, resources: itemResources) {
                    allEntries.append(entry)
                }
                continue
            }

            // Handle directories recursively
            if itemResources.isDirectory == true && itemResources.isPackage != true {
                if !FileExclusionService.shared.shouldExclude(url: url, isDirectory: true) {
                    let subdirEntries = await scanDirectoryRecursively(url)
                    allEntries.append(contentsOf: subdirEntries)
                }
                continue
            }

            // Handle regular files
            if let entry = FileEntryFactory.createFileEntry(for: url, resources: itemResources) {
                allEntries.append(entry)
            }
        }

        return allEntries
    }

    /// Find directories that have changed since a given date
    static func findChangedDirectories(at directoryURL: URL, since lastIndexedDate: Date) async -> [String] {
        var changedDirectories: [String] = []

        // Check if the current directory has been modified
        guard let resources = safeFileSystemOperation({
            try directoryURL.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
        }) else {
            return changedDirectories
        }

        let dirModificationDate = resources.contentModificationDate ?? Date.distantPast

        // If directory itself has changed, mark it for rebuild
        if dirModificationDate > lastIndexedDate {
            changedDirectories.append(directoryURL.path)
            return changedDirectories // No need to check subdirectories
        }

        // Directory hasn't changed, check its subdirectories
        let options = getEnumerationOptions()

        guard let contents = safeFileSystemOperation({
            try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .contentModificationDateKey],
                options: options
            )
        }) else {
            return changedDirectories
        }

        // Check subdirectories
        for url in contents {
            guard let itemResources = safeFileSystemOperation({
                try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            }) else {
                continue
            }

            if itemResources.isDirectory == true && itemResources.isPackage != true {
                // Check if excluded
                if !FileExclusionService.shared.shouldExclude(url: url, isDirectory: true) {
                    let subChanges = await findChangedDirectories(at: url, since: lastIndexedDate)
                    changedDirectories.append(contentsOf: subChanges)
                }
            }
        }

        return changedDirectories
    }

}