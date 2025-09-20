import Foundation

/// Service responsible for indexing the filesystem into the database
class IndexingService {
    private let batchSize = SeekConfig.Indexing.batchSize
    private let databaseService = DatabaseService.shared

    // MARK: - Public Methods

    /// Perform a full indexing of the filesystem
    /// - Parameter scanPaths: Root paths to scan (defaults to config)
    func performFullIndexing(scanPaths: [String] = SeekConfig.Indexing.defaultScanPaths) async throws {
        print("🔄 Starting full indexing...")
        let stats = IndexingStatistics()

        // Start by clearing out the database if needed

        let existingCount = try await databaseService.getFileCount()

        if existingCount > 0 {
            print("📦 Clearing existing database with \(existingCount) entries...")
            try await databaseService.clearAllFileEntries()
            try await databaseService.clearIndexingStatus()
        }

        // Once the database is clear, we perform the bulk indexing. 
        // We first prepare the database.

        // Begin bulk indexing
        try await databaseService.beginBulkIndexing()

        // Next, we start the bulk indexing from the scan paths and let 
        // concurrency and recursion handle the rest.

        // Process all scan paths
        var totalCount = 0
        for rootPath in scanPaths {
            guard FileManager.default.fileExists(atPath: rootPath) else {
                print("⚠️ Skipping non-existent path: \(rootPath)")
                continue
            }

            let rootURL = URL(fileURLWithPath: rootPath)
            totalCount += try await indexRootPath(rootURL, stats: stats)
        }

        // Finally, we commit and update the medata.

        // Commit and update metadata
        try await databaseService.commitBulkIndexing()
        let dbCount = try await databaseService.getFileCount()
        try await databaseService.markAsIndexed(paths: scanPaths, fileCount: dbCount)

        // At this point, we are done.

        stats.printFullIndexingStats(totalCount: totalCount, dbCount: dbCount)
    }


    // MARK: - Private Methods

    /// Index a single root path and all its contents
    private func indexRootPath(_ rootURL: URL, stats: IndexingStatistics) async throws -> Int {
        var totalCount = 0
        print("📁 Indexing: \(rootURL.path)")

        // First, scan root-level files
        let rootFiles = FileSystemScanner.scanRootLevelFiles(at: rootURL)
        if !rootFiles.isEmpty {
            for chunk in rootFiles.chunked(into: batchSize) {
                try await databaseService.insertBatch(chunk)
                totalCount += chunk.count
                stats.addProcessedCount(chunk.count)
            }
        }

        // Get top-level directories and process them with parallelism
        let directories = FileSystemScanner.getTopLevelDirectories(at: rootURL)
        let workQueue = WorkQueueCoordinator<URL>()

        // Enqueue all directories
        workQueue.enqueueAll(directories)

        // Process directories in parallel
        let maxConcurrency = SeekConfig.Indexing.Concurrency.fullIndexing
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<maxConcurrency {
                group.addTask { [weak self] in
                    guard let self = self else { return 0 }
                    var workerTotal = 0

                    workQueue.addWorker()
                    defer { workQueue.removeWorker() }

                    while let dirURL = await workQueue.dequeueForWorker() {
                        let entries = await self.processDirectory(dirURL, workQueue: workQueue, stats: stats)
                        workQueue.workerFinishedItem()

                        if !entries.isEmpty {
                            for chunk in entries.chunked(into: self.batchSize) {
                                try? await self.databaseService.insertBatch(chunk)
                                workerTotal += chunk.count
                                stats.addProcessedCount(chunk.count)
                            }
                        }
                    }
                    return workerTotal
                }
            }

            for await workerCount in group {
                totalCount += workerCount
            }
        }

        return totalCount
    }

    /// Process a single directory and enqueue subdirectories
    private func processDirectory(_ directoryURL: URL, workQueue: WorkQueueCoordinator<URL>, stats: IndexingStatistics) async -> [FileEntry] {
        var entries: [FileEntry] = []

        // Add the directory itself
        if let dirEntry = FileEntryFactory.createFileEntry(for: directoryURL) {
            entries.append(dirEntry)
        }

        // Get enumeration options
        let options = FileSystemScanner.getEnumerationOptions()

        // Get directory contents
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: SeekConfig.Indexing.resourceKeys + [.isPackageKey],
            options: options
        ) else {
            return entries
        }

        // Process each item
        for url in contents {
            guard let resources = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]
            ) else {
                continue
            }

            // Skip symlinks
            if resources.isSymbolicLink == true {
                stats.incrementSymlinkCount()
                continue
            }

            // Check exclusions
            let isDirectory = resources.isDirectory ?? false
            if FileExclusionService.shared.shouldExclude(url: url, isDirectory: isDirectory) {
                stats.incrementExcludedCount()
                continue
            }

            // Handle packages as files
            if resources.isPackage == true {
                if let entry = FileEntryFactory.createFileEntry(for: url, resources: resources) {
                    entries.append(entry)
                }
                continue
            }

            // Queue subdirectories for processing
            if isDirectory && resources.isPackage != true {
                workQueue.enqueue(url)
                continue
            }

            // Handle regular files
            if let entry = FileEntryFactory.createFileEntry(for: url, resources: resources) {
                entries.append(entry)
            }
        }

        return entries
    }


}

