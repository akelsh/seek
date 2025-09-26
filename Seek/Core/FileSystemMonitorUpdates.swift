import Foundation

// -------------------------
// MARK: - Update Processing
// -------------------------

extension FileSystemMonitor {

    // MARK: - Update Queue Management

    internal func queuePathForUpdate(_ path: String) {
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

    internal func processPendingUpdates() {
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

        // Cancel timer since we're processing now
        DispatchQueue.main.async { [weak self] in
            self?.updateTimer?.invalidate()
            self?.updateTimer = nil
        }
    }
    
    // -------------------------------------
    // MARK: - File System Change Processing
    // -------------------------------------

    private func processFileSystemChanges(paths: [String]) {
        guard !paths.isEmpty else { return }

        Task {
            do {
                // Batch process all paths
                var entriesToUpsert: [FileEntry] = []
                var pathsToDelete: [String] = []

                for path in paths {
                    if FileManager.default.fileExists(atPath: path) {
                        // File/directory exists - create or update entry
                        let url = URL(fileURLWithPath: path)
                        if let entry = FileEntryFactory.createFileEntry(for: url) {
                            entriesToUpsert.append(entry)
                        }
                    } else {
                        // File/directory was deleted
                        pathsToDelete.append(path)
                    }
                }

                // Batch database operations
                try await performDatabaseUpdates(entriesToUpsert: entriesToUpsert, pathsToDelete: pathsToDelete)

                logger.fileSystemInfo("Processed \(paths.count) file system changes: \(entriesToUpsert.count) upserts, \(pathsToDelete.count) deletions")

            } catch {
                logger.fileSystemError("Error processing file system batch: \(error)")
            }
        }
    }

    private func performDatabaseUpdates(entriesToUpsert: [FileEntry], pathsToDelete: [String]) async throws {
        // Upsert entries for files that exist
        if !entriesToUpsert.isEmpty {
            try await databaseService.batchUpsertEntries(entriesToUpsert)
        }

        // Delete entries for files that no longer exist
        if !pathsToDelete.isEmpty {
            try await databaseService.batchRemoveEntries(pathsToDelete)
        }
    }
    
    // --------------------------
    // MARK: - Validation Helpers
    // --------------------------

    internal func validateFileSystemEvent(path: String, flags: FSEventStreamEventFlags) -> Bool {
        // Check event type
        let isRemoved = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0
        let isRenamed = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)) != 0

        // For removal and rename events, the path may not exist (which is expected)
        // For creation events, validate the path exists
        if !isRemoved && !isRenamed {
            let fileExists = FileManager.default.fileExists(atPath: path)
            if !fileExists {
                // This is likely a historical event for a file that no longer exists
                return false
            }
        }

        return true
    }
    
    // --------------------------------------
    // MARK: - Batch Processing Configuration
    // --------------------------------------

    internal func configureBatchProcessing(batchSize: Int? = nil, maxBatchDelay: TimeInterval? = nil) {
        if let size = batchSize {
            self.batchSize = size
        }
        if let delay = maxBatchDelay {
            self.maxBatchDelay = delay
        }
    }
    
    // -------------------------
    // MARK: - Update Statistics
    // -------------------------

    internal func getUpdateQueueStatus() -> (pendingCount: Int, hasPendingTimer: Bool) {
        var pendingCount = 0
        var hasPendingTimer = false

        pendingUpdatesQueue.sync {
            pendingCount = self.pendingUpdates.count
        }

        DispatchQueue.main.sync {
            hasPendingTimer = self.updateTimer != nil
        }

        return (pendingCount, hasPendingTimer)
    }

    internal func flushPendingUpdates() {
        // Force immediate processing of any pending updates
        processPendingUpdates()
    }
}
