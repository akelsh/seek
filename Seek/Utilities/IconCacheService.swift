import Foundation
import AppKit
import UniformTypeIdentifiers

/// Service responsible for caching and managing file icons
class IconCacheService {
    static let shared = IconCacheService()
    
    // --------------------------
    // MARK: - Private Properties
    // --------------------------
    
    private var iconCache: [String: NSImage] = [:]
    private let iconCacheQueue = DispatchQueue(label: "com.seek.iconCache") // Serial queue for thread safety
    private let iconLoadingQueue = DispatchQueue(label: "com.seek.iconLoading", attributes: .concurrent)
    private let logger = LoggingService.shared

    private init() {
        logger.debug("IconCacheService: Initialized")
    }
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Get icon for a file path with cancellation-safe caching (optimized for search performance)
    func icon(for path: String) -> NSImage {
        guard let validPath = validateAndSanitizePath(path) else {
            return getDefaultIcon()
        }

        return iconCacheQueue.sync { [weak self] in
            guard let self = self else { return getDefaultIcon() }

            do {
                guard validateCacheKey(validPath) else {
                    return getDefaultIcon()
                }

                if let cached = self.safelyAccessCache(for: validPath) {
                    return cached
                }

                // PERFORMANCE OPTIMIZATION: Don't load icons synchronously during search
                // Return default icon immediately and load real icon in background
                self.loadIconAsynchronously(for: validPath)
                return getDefaultIcon()
            } catch {
                logger.error("IconCacheService: Unexpected error accessing icon cache: \(error)")
                return getDefaultIcon()
            }
        }
    }
    
    // ------------------------------
    // MARK: - Private Helper Methods
    // ------------------------------

    /// Load icon asynchronously without blocking UI
    private func loadIconAsynchronously(for path: String) {
        iconLoadingQueue.async { [weak self] in
            guard let self = self else { return }

            // Load icon on background queue
            let icon = NSWorkspace.shared.icon(forFile: path)

            // Store in cache if valid
            if self.validateIconForCaching(icon) {
                self.iconCacheQueue.sync {
                    self.atomicallyStoreInCache(icon: icon, forPath: path)
                }

                // Notify UI to refresh (icon is now available in cache)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("IconCacheUpdated"),
                        object: nil,
                        userInfo: ["path": path]
                    )
                }
            }
        }
    }

    /// Validate and sanitize incoming path parameter
    private func validateAndSanitizePath(_ path: Any) -> String? {
        guard let stringPath = path as? String else {
            return nil
        }

        guard !stringPath.isEmpty else {
            return nil
        }

        guard stringPath.isValidFilePath else {
            return nil
        }

        return stringPath
    }

    /// Validate cache key to prevent type confusion
    private func validateCacheKey(_ key: String) -> Bool {
        // Ensure the key is not empty (type is already guaranteed by parameter)
        return !key.isEmpty
    }

    /// Validate icon object before caching
    private func validateIconForCaching(_ icon: NSImage?) -> Bool {
        guard let icon = icon else { return false }
        return icon.isValid && !icon.size.equalTo(.zero)
    }

    /// Get default icon using modern API
    private func getDefaultIcon() -> NSImage {
        if #available(macOS 11.0, *) {
            return NSWorkspace.shared.icon(for: .data)
        } else {
            // Fallback for older macOS versions
            return NSWorkspace.shared.icon(forFileType: "public.data")
        }
    }

    /// Preload icons for multiple file entries in the background
    func preloadIcons(for entries: [FileEntry], limit: Int = 50) {
        iconLoadingQueue.async { [weak self] in
            guard let self = self else { return }

            for entry in entries.prefix(limit) {
                guard let validPath = self.validateAndSanitizePath(entry.fullPath) else {
                    continue
                }

                self.iconCacheQueue.sync {
                    do {
                        guard self.validateCacheIntegrity() else {
                            self.iconCache.removeAll()
                            return
                        }

                        if self.safelyAccessCache(for: validPath) == nil {
                            let icon = NSWorkspace.shared.icon(forFile: validPath)
                            if self.validateIconForCaching(icon) {
                                self.atomicallyStoreInCache(icon: icon, forPath: validPath)
                            }
                        }
                    } catch {
                        // Silent error handling for preload
                    }
                }
            }
        }
    }

    /// Clear the icon cache with enhanced safety
    func clearCache() {
        iconCacheQueue.sync {
            recreateCache()
        }
    }

    /// Handle search cancellation gracefully without corrupting cache
    func handleSearchCancellation() {
        // Don't need to do anything special - our atomic operations prevent corruption
    }

    /// Get cache statistics with integrity check
    func getCacheStats() -> (count: Int, memoryEstimate: String) {
        return iconCacheQueue.sync {
            if !validateCacheIntegrity() {
                recreateCache()
            }

            let count = safeCacheCount()
            let memoryEstimate = ByteCountFormatter.string(fromByteCount: Int64(count * 32 * 32 * 4), countStyle: .memory)
            return (count, memoryEstimate)
        }
    }

    /// Validate cache integrity to prevent type confusion crashes
    private func validateCacheIntegrity() -> Bool {
        // Check for empty keys or invalid NSImage values that might cause crashes
        for (key, value) in iconCache {
            // Ensure key is not empty
            guard !key.isEmpty else {
                logger.error("IconCacheService: Empty cache key detected")
                return false
            }

            // Additional validation for NSImage
            if !value.isValid {
                logger.error("IconCacheService: Invalid NSImage in cache for key '\(key)'")
                return false
            }
        }
        return true
    }

    /// Safely access cache with error handling for NSException and type confusion
    private func safelyAccessCache(for path: String) -> NSImage? {
        do {
            // First, try to safely access the cache without checking count
            // If the cache object is corrupted, even .count can crash
            let cachedIcon = iconCache[path]
            return cachedIcon
        } catch {
            logger.error("IconCacheService: Error accessing cache for path '\(path)': \(error)")
            // Recreate the cache dictionary to fix corruption
            recreateCache()
            return nil
        }
    }

    /// Safely store icon in cache with error handling
    private func safelyStoreInCache(icon: NSImage, forPath path: String) {
        atomicallyStoreInCache(icon: icon, forPath: path)
    }

    /// Atomically store icon in cache - operation either succeeds completely or leaves cache unchanged
    private func atomicallyStoreInCache(icon: NSImage, forPath path: String) {
        do {
            // Validate before storing
            guard !path.isEmpty && icon.isValid else {
                logger.error("IconCacheService: Refusing to store invalid icon or empty path")
                return
            }

            // Create a copy of the cache for atomic operation
            var newCache = iconCache
            newCache[path] = icon

            // Only update the actual cache if everything succeeded
            iconCache = newCache
        } catch {
            logger.error("IconCacheService: Error storing icon in cache for path '\(path)': \(error)")
            // Don't modify cache if there was an error
        }
    }

    /// Recreate the cache dictionary to fix corruption
    private func recreateCache() {
        iconCache = [:]
    }

    /// Safely get cache count with error handling
    private func safeCacheCount() -> Int {
        do {
            return iconCache.count
        } catch {
            logger.error("IconCacheService: Error accessing cache count: \(error)")
            recreateCache()
            return 0
        }
    }
}

