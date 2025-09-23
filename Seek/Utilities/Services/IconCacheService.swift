import Foundation
import AppKit

/// Service responsible for caching and managing file icons
class IconCacheService {
    static let shared = IconCacheService()

    // MARK: - Private Properties
    private var iconCache: [String: NSImage] = [:]
    private let iconCacheQueue = DispatchQueue(label: "com.seek.iconCache", attributes: .concurrent)
    private let iconLoadingQueue = DispatchQueue(label: "com.seek.iconLoading", attributes: .concurrent)
    private let logger = LoggingService.shared

    private init() {
        logger.debug("IconCacheService: Initialized")
    }

    // MARK: - Public Methods

    /// Get icon for a file path with thread-safe caching
    func icon(for path: String) -> NSImage {
        logger.debug("IconCacheService: Getting icon for path: '\(path)'")

        // Ensure path is a proper string to avoid NSNumber crashes
        guard !path.isEmpty else {
            logger.debug("IconCacheService: Path is empty, returning default icon")
            return NSWorkspace.shared.icon(forFileType: "public.data")
        }

        let safePath = String(describing: path)

        // Additional safety check - ensure it's really a string
        guard safePath.isValidFilePath else {
            logger.debug("IconCacheService: Invalid file path: '\(safePath)', returning default icon")
            return NSWorkspace.shared.icon(forFileType: "public.data")
        }

        // Thread-safe cache access
        return iconCacheQueue.sync {
            if let cached = iconCache[safePath] {
                logger.debug("IconCacheService: Cache hit for path: '\(safePath)'")
                return cached
            }

            logger.debug("IconCacheService: Cache miss for path: '\(safePath)', loading icon")
            let icon = NSWorkspace.shared.icon(forFile: safePath)
            iconCache[safePath] = icon
            logger.debug("IconCacheService: Icon cached for path: '\(safePath)', cache size: \(iconCache.count)")
            return icon
        }
    }

    /// Preload icons for multiple file entries in the background
    func preloadIcons(for entries: [FileEntry], limit: Int = 50) {
        let entriesToPreload = min(entries.count, limit)
        logger.debug("IconCacheService: Starting preload for \(entriesToPreload) icons")

        iconLoadingQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            var loadedCount = 0
            for entry in entries.prefix(limit) {
                // Thread-safe cache check and update
                self.iconCacheQueue.sync {
                    if self.iconCache[entry.fullPath] == nil {
                        self.logger.debug("IconCacheService: Preloading icon for: '\(entry.fullPath)'")
                        let icon = NSWorkspace.shared.icon(forFile: entry.fullPath)
                        self.iconCache[entry.fullPath] = icon
                        loadedCount += 1
                    } else {
                        self.logger.debug("IconCacheService: Icon already cached for: '\(entry.fullPath)'")
                    }
                }
            }
            self.logger.debug("IconCacheService: Preload complete, loaded \(loadedCount) new icons, total cache size: \(self.iconCache.count)")
        }
    }

    /// Clear the icon cache
    func clearCache() {
        logger.debug("IconCacheService: Clearing icon cache")
        iconCacheQueue.sync {
            let previousCount = iconCache.count
            iconCache.removeAll()
            logger.debug("IconCacheService: Cache cleared, removed \(previousCount) icons")
        }
    }

    /// Get cache statistics
    func getCacheStats() -> (count: Int, memoryEstimate: String) {
        return iconCacheQueue.sync {
            let count = iconCache.count
            let memoryEstimate = ByteCountFormatter.string(fromByteCount: Int64(count * 32 * 32 * 4), countStyle: .memory)
            logger.debug("IconCacheService: Cache stats - count: \(count), estimated memory: \(memoryEstimate)")
            return (count, memoryEstimate)
        }
    }
}

