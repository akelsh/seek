import Foundation
import CoreServices

/// Monitors file system changes using FSEvents and updates the database in real-time
class FileSystemMonitor {

    // MARK: - Properties

    static let shared = FileSystemMonitor()

    private var eventStream: FSEventStreamRef?
    private let databaseService = DatabaseService.shared
    private let exclusionService = FileExclusionService.shared

    private let monitorQueue = DispatchQueue(label: "com.seek.filesystem.monitor", qos: .background)
    private let updateQueue = DispatchQueue(label: "com.seek.database.update", qos: .background)

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


    /// Smart monitoring startup with automatic indexing
    func startMonitoringWithRecovery() async -> String {
        do {
            // Always perform full indexing for consistency
            print("📁 Starting full indexing to ensure database is up to date")
            let indexingService = IndexingService()
            try await indexingService.performFullIndexing()
            print("✅ Full indexing completed")

            // Start fresh monitoring from current time
            await startMonitoringInternal()
            return "Monitoring active (fresh start after indexing)"

        } catch {
            print("❌ Error starting monitoring: \(error)")
            return "Error: \(error.localizedDescription)"
        }
    }

    /// Internal monitoring startup - always starts from current time
    private func startMonitoringInternal() async {
        guard eventStream == nil else {
            return
        }

        // Store monitoring paths
        monitoringPaths = SeekConfig.Indexing.defaultScanPaths
        let pathsToMonitor = monitoringPaths as CFArray

        // Always start from current time
        let startEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
        print("📁 Starting monitoring from current time")
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

        print("📁 Stopping monitoring...")

        // Stop the stream
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil

        // Cancel any pending updates
        updateTimer?.invalidate()
        updateTimer = nil
        pendingUpdates.removeAll()
    }

    // MARK: - Private Methods


    private func handleFSEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIds: UnsafePointer<FSEventStreamEventId>) {
        let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

        for i in 0..<numEvents {
            let path = paths[i]
            let flags = eventFlags[i]

            // FIRST: Quick filter for structural changes only - exit early for content-only modifications
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
    }

    private func handleFileSystemEvent(path: String, flags: FSEventStreamEventFlags) {
        // At this point, we know it's a structural change (filtering done earlier)

        // Add to pending updates for batching
        pendingUpdates.insert(path)

        // Process immediately if batch is full, or schedule timer for smaller batches
        if pendingUpdates.count >= batchSize {
            updateTimer?.invalidate()
            processPendingUpdates()
        } else {
            // Batch updates - wait for more changes or timeout
            updateTimer?.invalidate()
            DispatchQueue.main.async { [weak self] in
                self?.updateTimer = Timer.scheduledTimer(withTimeInterval: self?.maxBatchDelay ?? 2.0, repeats: false) { [weak self] _ in
                    self?.processPendingUpdates()
                }
            }
        }
    }

    private func processPendingUpdates() {
        guard !pendingUpdates.isEmpty else { return }

        let pathsToUpdate = Array(pendingUpdates)
        pendingUpdates.removeAll()

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
                print("❌ Error processing file system batch: \(error)")
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

