import Foundation

/// Coordinates work queue processing to prevent premature worker exit
class WorkQueueCoordinator<T> {
    private let queue: ConcurrentQueue<T>
    private let lock = NSLock()
    private var busyWorkers = 0  // Workers actively processing
    private var totalWorkers = 0  // Total worker count
    private var isCompleted = false

    init() {
        self.queue = ConcurrentQueue<T>()
    }

    /// Enqueue work items
    func enqueue(_ item: T) {
        queue.enqueue(item)
    }

    /// Enqueue multiple work items
    func enqueueAll(_ items: [T]) {
        queue.enqueueAll(items)
    }

    /// Register a worker
    func addWorker() {
        lock.lock()
        totalWorkers += 1
        lock.unlock()
    }

    /// Unregister a worker
    func removeWorker() {
        lock.lock()
        totalWorkers -= 1
        if totalWorkers == 0 {
            isCompleted = true
        }
        lock.unlock()
    }

    /// Try to get next work item with proper completion detection
    func dequeueForWorker() async -> T? {
        while true {
            // Try to get work
            if let item = queue.dequeue() {
                // Mark worker as busy before returning work
                markWorkerBusy()
                return item
            }

            // No work available - check if we should exit
            let shouldExit = checkShouldExit()

            if shouldExit {
                return nil  // Signal worker to exit
            }

            // Other workers still processing, wait a bit
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
    }

    private func markWorkerBusy() {
        lock.lock()
        busyWorkers += 1
        lock.unlock()
    }

    /// Called when worker finishes processing an item
    func workerFinishedItem() {
        lock.lock()
        busyWorkers -= 1
        lock.unlock()
    }

    private func checkShouldExit() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // If queue has work, don't exit
        if !queue.isEmpty {
            return false
        }

        // Queue is empty - check if any workers are still processing
        // If no workers are busy and queue is empty, we're done
        if busyWorkers == 0 {
            isCompleted = true
            return true
        }

        // Some workers still processing (might add more work)
        return false
    }

    /// Check if all work is complete
    var isDone: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCompleted || (totalWorkers == 0 && queue.isEmpty)
    }
}