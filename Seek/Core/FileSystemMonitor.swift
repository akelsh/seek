import Foundation
import CoreServices

/// Monitors file system changes using FSEvents and updates the database in real-time
class FileSystemMonitor {

    // MARK: - Properties

    static let shared = FileSystemMonitor()

    private var eventStream: FSEventStreamRef?
    private let databaseService = DatabaseService.shared
    private let exclusionService = FileExclusionService.shared
    private let logger = LoggingService.shared

    private let monitorQueue = DispatchQueue(label: "com.seek.filesystem.monitor", qos: .background)
    private let updateQueue = DispatchQueue(label: "com.seek.database.update", qos: .background)
    private let pendingUpdatesQueue = DispatchQueue(label: "com.seek.pendingupdates", attributes: .concurrent)

    // Batching for rapid changes
    private var pendingUpdates: Set<String> = []
    private var updateTimer: Timer?
    private let batchSize = 50
    private let maxBatchDelay: TimeInterval = 2.0

    // Monitoring paths
    private var monitoringPaths: [String] = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Start monitoring file system changes
    func startMonitoring() {
        Task {
            await startMonitoringInternal()
        }
    }

    /// Check if a stored FSEvent ID is still valid on the system
    func isEventIdValid(_ eventId: FSEventStreamEventId, for paths: [String]) -> Bool {
        // Create a temporary event stream to test the event ID
        let pathsToMonitor = paths as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: nil,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, _, _, _, _, _ in
            // Empty callback - we just need to test if the stream can be created
        }

        guard let testStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToMonitor,
            eventId,
            0.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            return false
        }

        // If we can create the stream, the event ID is valid
        FSEventStreamRelease(testStream)
        return true
    }


    /// Smart monitoring startup with automatic indexing
    func startMonitoringWithRecovery() async -> String {
        do {
            // Use smart indexing to determine best approach
            logger.fileSystemInfo("Starting smart indexing analysis")
            let indexingService = IndexingService()
            try await indexingService.performSmartIndexing()
            logger.fileSystemInfo("Smart indexing completed")

            // Start monitoring (will use stored event ID if available and valid)
            await startMonitoringInternal()
            return "Monitoring active with smart indexing"

        } catch {
            logger.fileSystemError("Error starting monitoring: \(error)")
            return "Error: \(error.localizedDescription)"
        }
    }

    /// Internal monitoring startup - uses stored event ID when available
    private func startMonitoringInternal() async {
        guard eventStream == nil else {
            return
        }

        // Store monitoring paths
        monitoringPaths = SeekConfig.Indexing.defaultScanPaths
        let pathsToMonitor = monitoringPaths as CFArray

        // Try to get stored event ID, fallback to current time
        let startEventId: FSEventStreamEventId
        do {
            if let storedEventId = try await databaseService.getLastEventId(),
               isEventIdValid(storedEventId, for: monitoringPaths) {
                startEventId = storedEventId
                logger.fileSystemInfo("Starting monitoring from stored event ID: \(storedEventId)")
            } else {
                startEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
                logger.fileSystemInfo("Starting monitoring from current time (no valid stored event ID)")
            }
        } catch {
            startEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
            logger.fileSystemInfo("Starting monitoring from current time (error reading stored event ID: \(error))")
        }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let callbackInfo = clientCallBackInfo else { return }
            let monitor = Unmanaged<FileSystemMonitor>.fromOpaque(callbackInfo).takeUnretainedValue()
            monitor.handleFSEvents(
                numEvents: numEvents,
                eventPaths: eventPaths,
                eventFlags: eventFlags,
                eventIds: eventIds
            )
        }

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToMonitor,
            startEventId,
            1.0, // Latency in seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        guard let stream = eventStream else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, monitorQueue)

        if !FSEventStreamStart(stream) {
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    /// Stop monitoring file system changes
    func stopMonitoring() {
        guard let stream = eventStream else { return }

        logger.fileSystemInfo("Stopping monitoring")

        // Stop the stream
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil

        // Cancel any pending updates
        DispatchQueue.main.async { [weak self] in
            self?.updateTimer?.invalidate()
            self?.updateTimer = nil
        }
        pendingUpdates.removeAll()
    }

    // MARK: - Private Methods


    private func handleFSEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIds: UnsafePointer<FSEventStreamEventId>) {
        // Safely cast the paths array
        guard let pathsArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] else {
            logger.fileSystemError("Failed to cast FSEvents paths to String array")
            return
        }
        let paths = pathsArray

        // Track the latest event ID for persistence
        var latestEventId: FSEventStreamEventId = 0

        for i in 0..<numEvents {
            let path = paths[i]
            let flags = eventFlags[i]
            let eventId = eventIds[i]

            // Update latest event ID
            latestEventId = max(latestEventId, eventId)

            // Check for special FSEvent flags first
            let isHistoryDone = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone)) != 0
            let isRootChanged = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged)) != 0
            let mustScanSubDirs = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs)) != 0
            let isKernelDropped = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped)) != 0
            let isUserDropped = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped)) != 0

            // Handle special flags
            if isHistoryDone {
                logger.fileSystemInfo("FSEvents history playback completed - now monitoring live changes")
                continue
            }

            if isRootChanged {
                logger.fileSystemInfo("Root changed event for path: \(path)")
                // May need to rescan the entire directory
                continue
            }

            if mustScanSubDirs {
                logger.fileSystemInfo("Must scan subdirectories for path: \(path)")
                // Events were coalesced, need to rescan
                continue
            }

            if isKernelDropped || isUserDropped {
                logger.fileSystemError("Events were dropped - may have missed file system changes")
                continue
            }

            // Check for structural changes
            let isCreated = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)) != 0
            let isRemoved = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0
            let isRenamed = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)) != 0
            let _ = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)) != 0

            // Skip content-only modifications immediately to reduce overhead
            if !isCreated && !isRemoved && !isRenamed {
                continue
            }

            // SECOND: Check exclusions only for structural changes
            let url = URL(fileURLWithPath: path)
            let fileName = url.lastPathComponent
            let isDirectory = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir)) != 0

            if exclusionService.shouldExclude(path: path, name: fileName, isDirectory: isDirectory) {
                continue
            }

            handleFileSystemEvent(path: path, flags: flags)
        }

        // Store the latest event ID after processing all events
        if latestEventId > 0 {
            Task {
                do {
                    try await databaseService.storeLastEventId(latestEventId)
                } catch {
                    logger.fileSystemError("Failed to store event ID: \(error)")
                }
            }
        }
    }

    private func handleFileSystemEvent(path: String, flags: FSEventStreamEventFlags) {
        // At this point, we know it's a structural change (filtering done earlier)

        // Check event type
        let isRemoved = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0
        let isRenamed = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)) != 0

        // For removal and rename events, the path may not exist (which is expected)
        // For creation events, validate the path exists
        if !isRemoved && !isRenamed {
            let fileExists = FileManager.default.fileExists(atPath: path)
            if !fileExists {
                // This is likely a historical event for a file that no longer exists
                // Don't log at debug level to avoid spam during history playback
                return
            }
        }

        // Add to pending updates for batching with thread safety
        pendingUpdatesQueue.async(flags: .barrier) {
            self.pendingUpdates.insert(path)
        }

        // Process immediately if batch is full, or schedule timer for smaller batches
        pendingUpdatesQueue.sync {
            guard self.pendingUpdates.count >= self.batchSize else {
                // Schedule timer for smaller batch
                self.scheduleUpdateTimer()
                return
            }
        }

        // Batch is full, process immediately
        
        processPendingUpdates()
    }

    private func scheduleUpdateTimer() {
        // Batch updates - wait for more changes or timeout
        DispatchQueue.main.async { [weak self] in
            self?.updateTimer?.invalidate()
            self?.updateTimer = Timer.scheduledTimer(withTimeInterval: self?.maxBatchDelay ?? 2.0, repeats: false) { [weak self] _ in
                self?.processPendingUpdates()
            }
        }
    }

    private func processPendingUpdates() {
        var pathsToUpdate: [String] = []

        pendingUpdatesQueue.sync(flags: .barrier) {
            guard !self.pendingUpdates.isEmpty else { return }
            pathsToUpdate = Array(self.pendingUpdates)
            self.pendingUpdates.removeAll()
        }

        guard !pathsToUpdate.isEmpty else { return }

        updateQueue.async { [weak self] in
            self?.processFileSystemChanges(paths: pathsToUpdate)
        }
    }

    private func processFileSystemChanges(paths: [String]) {
        guard !paths.isEmpty else { return }

        Task {
            do {
                // Batch process all paths
                var entriesToUpsert: [FileEntry] = []
                var pathsToDelete: [String] = []

                for path in paths {
                    if FileManager.default.fileExists(atPath: path) {
                        if let entry = try await createFileEntry(for: path) {
                            entriesToUpsert.append(entry)
                        }
                    } else {
                        pathsToDelete.append(path)
                    }
                }

                // Batch database operations
                if !entriesToUpsert.isEmpty {
                    try await databaseService.performWrite { db in
                        let sql = """
                            INSERT OR REPLACE INTO file_entries (name, full_path, is_directory, file_extension, size, date_modified)
                            VALUES (?, ?, ?, ?, ?, ?)
                        """
                        let statement = try db.prepare(sql)

                        for entry in entriesToUpsert {
                            try statement.run(
                                entry.name,
                                entry.fullPath,
                                entry.isDirectory,
                                entry.fileExtension,
                                entry.size,
                                entry.dateModified
                            )
                        }
                    }
                }

                if !pathsToDelete.isEmpty {
                    try await databaseService.performWrite { db in
                        let sql = "DELETE FROM file_entries WHERE full_path = ?"
                        let statement = try db.prepare(sql)

                        for path in pathsToDelete {
                            try statement.run(path)
                        }
                    }
                }
            } catch {
                logger.fileSystemError("Error processing file system batch: \(error)")
            }
        }
    }

    private func createFileEntry(for path: String) async throws -> FileEntry? {
        let url = URL(fileURLWithPath: path)

        // Get file attributes
        let resourceValues = try url.resourceValues(forKeys: [
            .nameKey,
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isPackageKey,
            .isSymbolicLinkKey
        ])

        guard let name = resourceValues.name,
              let isDirectory = resourceValues.isDirectory,
              let modificationDate = resourceValues.contentModificationDate else {
            return nil
        }

        // Skip packages and symbolic links
        if resourceValues.isPackage == true || resourceValues.isSymbolicLink == true {
            return nil
        }

        let fileExtension = isDirectory ? nil : url.pathExtension.lowercased()

        return FileEntry(
            name: name,
            fullPath: url.path,
            isDirectory: isDirectory,
            fileExtension: fileExtension?.isEmpty == false ? fileExtension : nil,
            size: resourceValues.fileSize.map { Int64($0) },
            dateModified: modificationDate
        )
    }


}

