import Foundation
import CoreServices

class FileSystemMonitor {

    // -----------------
    // MARK: - Singleton
    // -----------------

    static let shared = FileSystemMonitor()

    // ------------------
    // MARK: - Properties
    // ------------------

    private var eventStream: FSEventStreamRef?
    internal let databaseService = DatabaseService.shared
    internal let exclusionService = FileExclusionService.shared
    internal let logger = LoggingService.shared

    internal let monitorQueue = DispatchQueue(label: "com.seek.filesystem.monitor", qos: .background)
    internal let updateQueue = DispatchQueue(label: "com.seek.database.update", qos: .background)
    internal let pendingUpdatesQueue = DispatchQueue(label: "com.seek.pendingupdates", attributes: .concurrent)

    // Batch processing state
    internal var pendingUpdates: Set<String> = []
    internal var updateTimer: Timer?
    internal var batchSize = 50
    internal var maxBatchDelay: TimeInterval = 2.0

    // Monitoring paths
    private var monitoringPaths: [String] = []

    // ----------------------
    // MARK: - Initialization
    // ----------------------

    private init() {}

    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    func startMonitoring() {
        Task {
            await startMonitoringInternal()
        }
    }

    func startMonitoringWithRecovery() async {
        logger.fileSystemInfo("FileSystemMonitor: Starting monitoring with recovery")
        await startMonitoringInternal()
    }

    private func startMonitoringInternal() async {
        // Stop existing monitoring first
        stopMonitoring()

        let pathsToMonitor = SeekConfig.Indexing.defaultScanPaths
        logger.fileSystemInfo("Starting file system monitoring for paths: \(pathsToMonitor)")

        // Get the last processed event ID for crash recovery
        var lastEventId: FSEventStreamEventId? = nil
        do {
            lastEventId = try await databaseService.getLastEventId()
            if let eventId = lastEventId {
                logger.fileSystemInfo("Resuming from event ID: \(eventId)")
            }
        } catch {
            logger.fileSystemError("Failed to get last event ID: \(error)")
        }

        // Create and start the event stream
        guard let stream = createEventStream(paths: pathsToMonitor, sinceEventId: lastEventId) else {
            logger.fileSystemError("Failed to create FSEvent stream")
            return
        }

        eventStream = stream
        monitoringPaths = pathsToMonitor

        if startEventStream(stream) {
            logger.fileSystemInfo("FileSystemMonitor: File system monitoring started successfully for paths: \(pathsToMonitor)")
            logger.fileSystemInfo("FileSystemMonitor: Monitoring is now active with event stream")
        } else {
            logger.fileSystemError("FileSystemMonitor: Failed to start file system monitoring")
            stopMonitoring()
        }
    }

    func stopMonitoring() {
        logger.fileSystemInfo("Stopping file system monitoring")

        guard let stream = eventStream else { return }

        stopEventStream(stream)
        eventStream = nil

        // Cancel any pending updates
        DispatchQueue.main.async { [weak self] in
            self?.updateTimer?.invalidate()
            self?.updateTimer = nil
        }
        pendingUpdates.removeAll()
    }
    
    // ----------------------
    // MARK: - Status Methods
    // ----------------------

    func isMonitoring() -> Bool {
        return eventStream != nil
    }

    func getMonitoringPaths() -> [String] {
        return monitoringPaths
    }

    func getMonitoringStatus() -> (isActive: Bool, paths: [String], pendingUpdates: Int) {
        let status = getUpdateQueueStatus()
        return (isMonitoring(), monitoringPaths, status.pendingCount)
    }

    func isEventIdValid(_ eventId: FSEventStreamEventId, for paths: [String]) -> Bool {
        // For now, assume event ID is valid if it's greater than 0
        // In a more sophisticated implementation, we might check if the event ID
        // is still within the FSEvents history window
        return eventId > 0
    }
}
