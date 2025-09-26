import Foundation

/// Service responsible for indexing the filesystem into the database
class IndexingService {
    private let batchSize = SeekConfig.Indexing.batchSize
    private let databaseService = DatabaseService.shared
    private let logger = LoggingService.shared

    // Progress reporting
    typealias ProgressCallback = (Double, Int, Int, String?) async -> Void
    private var progressCallback: ProgressCallback?
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Set progress callback for indexing operations
    /// - Parameter callback: Called with (progress: Double, filesProcessed: Int, totalFiles: Int, message: String?)
    func setProgressCallback(_ callback: @escaping ProgressCallback) {
        self.progressCallback = callback
    }

    /// Perform smart indexing - either full or incremental based on database state
    /// - Parameter scanPaths: Root paths to scan (defaults to config)
    func performSmartIndexing(scanPaths: [String] = SeekConfig.Indexing.defaultScanPaths) async throws {
        logger.indexingInfo("Starting smart indexing analysis")

        // Check if database is indexed and has a valid event ID
        let isIndexed = try await databaseService.isIndexed()
        let lastEventId = try await databaseService.getLastEventId()

        if isIndexed, let eventId = lastEventId {
            // Validate the event ID with FileSystemMonitor
            let monitor = FileSystemMonitor.shared
            if monitor.isEventIdValid(eventId, for: scanPaths) {
                logger.indexingInfo("Database is indexed with valid event ID \(eventId) - incremental updates will be handled by monitoring")
                return
            } else {
                logger.indexingInfo("Event ID \(eventId) is no longer valid - performing full reindex")
                try await performFullIndexing(scanPaths: scanPaths)
            }
        } else {
            logger.indexingInfo("No previous indexing found - performing full index")
            try await performFullIndexing(scanPaths: scanPaths)
        }
    }

    /// Perform a full indexing of the filesystem
    /// - Parameter scanPaths: Root paths to scan (defaults to config)
    func performFullIndexing(scanPaths: [String] = SeekConfig.Indexing.defaultScanPaths) async throws {
        logger.indexingInfo("Starting full indexing")
        let stats = IndexingStatistics()

        // Report initial progress
        await progressCallback?(0.0, 0, 0, "Getting things ready for you...")

        // Start by clearing out the database if needed
        let existingCount = try await databaseService.getFileCount()

        if existingCount > 0 {
            logger.indexingInfo("Clearing existing database with \(existingCount) entries")
            try await databaseService.recreateDatabase()
        } else {
            // Clear any stored event ID since we're doing a full index
            try await databaseService.clearLastEventId()
        }

        // Once the database is clear, we perform the bulk indexing. 
        // We first prepare the database.

        // Begin bulk indexing
        await progressCallback?(0.1, 0, 0, "Preparing your files...")
        try await databaseService.beginBulkIndexing()

        // Next, we start the bulk indexing from the scan paths and let
        // concurrency and recursion handle the rest.

        // Process all scan paths
        var totalCount = 0
        for (index, rootPath) in scanPaths.enumerated() {
            guard FileManager.default.fileExists(atPath: rootPath) else {
                logger.indexingInfo("Skipping non-existent path: \(rootPath)")
                continue
            }

            let rootURL = URL(fileURLWithPath: rootPath)

            // Report progress for each root path
            let baseProgress = Double(index) / Double(scanPaths.count) * 0.8 + 0.1  // Reserve 0.1-0.9 for scanning
            await progressCallback?(baseProgress, totalCount, 0, "Preparing your files...")

            totalCount += try await indexRootPath(rootURL, stats: stats, baseProgress: baseProgress, progressWeight: 0.8 / Double(scanPaths.count))
        }

        // Finally, we commit and update the metadata.

        // Commit and update metadata
        await progressCallback?(0.9, totalCount, totalCount, "Almost there...")
        try await databaseService.commitBulkIndexing()
        let dbCount = try await databaseService.getFileCount()
        try await databaseService.markAsIndexed(paths: scanPaths, fileCount: dbCount)

        // At this point, we are done.
        await progressCallback?(1.0, dbCount, dbCount, "All done!")

        stats.printFullIndexingStats(totalCount: totalCount, dbCount: dbCount)
    }

    // -----------------------
    // MARK: - Private Methods
    // -----------------------

    /// Index a single root path and all its contents
    private func indexRootPath(_ rootURL: URL, stats: IndexingStatistics, baseProgress: Double = 0.0, progressWeight: Double = 1.0) async throws -> Int {
        var totalCount = 0
        logger.indexingInfo("Indexing: \(rootURL.path)")

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

