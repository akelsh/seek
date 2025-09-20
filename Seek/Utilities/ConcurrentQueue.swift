import Foundation

/// Thread-safe concurrent queue for managing work items
class ConcurrentQueue<T> {
    private var items: [T] = []
    private let lock = NSLock()

    func enqueue(_ item: T) {
        lock.lock()
        defer { lock.unlock() }

        items.append(item)
    }

    func enqueueAll(_ items: [T]) {
        lock.lock()
        defer { lock.unlock() }

        self.items.append(contentsOf: items)
    }

    func dequeue() -> T? {
        lock.lock()
        defer { lock.unlock() }

        return items.isEmpty ? nil : items.removeFirst()
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }

        return items.isEmpty
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }

        return items.count
    }
}