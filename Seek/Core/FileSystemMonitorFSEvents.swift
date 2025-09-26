import Foundation
import CoreServices

// -------------------------
// MARK: - FSEvents Handling
// -------------------------

extension FileSystemMonitor {
    
    // ---------------------------
    // MARK: - FSEvents Processing
    // ---------------------------

    internal func handleFSEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIds: UnsafePointer<FSEventStreamEventId>) {
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

            // Process the event
            processFileSystemEvent(path: path, flags: flags, eventId: eventId)
        }

        // Store the latest event ID for crash recovery
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

    private func processFileSystemEvent(path: String, flags: FSEventStreamEventFlags, eventId: FSEventStreamEventId) {
        // Check for special FSEvent flags first
        let isHistoryDone = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone)) != 0
        let isRootChanged = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged)) != 0
        let mustScanSubDirs = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs)) != 0
        let isKernelDropped = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped)) != 0
        let isUserDropped = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped)) != 0

        // Handle special flags
        if isHistoryDone {
            logger.fileSystemInfo("FSEvents history playback completed - now monitoring live changes")
            return
        }

        if isRootChanged {
            logger.fileSystemInfo("Root changed event for path: \(path)")
            // May need to rescan the entire directory
            return
        }

        if mustScanSubDirs {
            logger.fileSystemInfo("Must scan subdirectories for path: \(path)")
            // Events were coalesced, need to rescan
            return
        }

        if isKernelDropped || isUserDropped {
            logger.fileSystemError("Events were dropped - may have missed file system changes")
            return
        }

        // Check for structural changes
        let isCreated = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)) != 0
        let isRemoved = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0
        let isRenamed = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)) != 0

        // Skip content-only modifications immediately to reduce overhead
        if !isCreated && !isRemoved && !isRenamed {
            return
        }

        // Check exclusions only for structural changes
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent
        let isDirectory = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir)) != 0

        // Apply exclusion rules
        if exclusionService.shouldExclude(path: path, name: fileName, isDirectory: isDirectory) {
            return
        }

        // Queue the path for processing
        queuePathForUpdate(path)
    }
    
    // -------------------------------
    // MARK: - Event Stream Management
    // -------------------------------

    internal func createEventStream(paths: [String], sinceEventId: FSEventStreamEventId?) -> FSEventStreamRef? {
        let pathsToWatch = paths.map { $0 as CFString } as CFArray

        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            let monitor = Unmanaged<FileSystemMonitor>.fromOpaque(clientCallBackInfo!).takeUnretainedValue()
            monitor.handleFSEvents(
                numEvents: numEvents,
                eventPaths: eventPaths,
                eventFlags: eventFlags,
                eventIds: eventIds
            )
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // Set stream creation flags
        let streamFlags: FSEventStreamCreateFlags =
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes) |
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents) |
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagIgnoreSelf)

        // Create the stream
        return FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            sinceEventId ?? FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1, // Latency in seconds
            streamFlags
        )
    }

    internal func startEventStream(_ stream: FSEventStreamRef) -> Bool {
        // Schedule the stream on the monitor queue
        FSEventStreamSetDispatchQueue(stream, monitorQueue)

        // Start the stream
        let started = FSEventStreamStart(stream)
        if started {
            logger.fileSystemInfo("FSEvent stream started successfully")
        } else {
            logger.fileSystemError("Failed to start FSEvent stream")
        }

        return started
    }

    internal func stopEventStream(_ stream: FSEventStreamRef) {
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)

        logger.fileSystemInfo("FSEvent stream stopped and released")
    }
}
