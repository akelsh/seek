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
    private let iconCacheQueue = DispatchQueue(label: "com.seek.iconCache", attributes: .concurrent)
    private let iconLoadingQueue = DispatchQueue(label: "com.seek.iconLoading", attributes: .concurrent)
    private let logger = LoggingService.shared

    private init() {
        logger.debug("IconCacheService: Initialized")
    }
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Get icon for a file path with thread-safe caching
    func icon(for path: String) -> NSImage {
        logger.debug("IconCacheService: Getting icon for path: '\(path)'")

        // Enhanced type safety: Ensure we're actually working with a String
        guard let validPath = validateAndSanitizePath(path) else {
            logger.debug("IconCacheService: Path validation failed, returning default icon")
            return getDefaultIcon()
        }

        // Thread-safe cache access
        return iconCacheQueue.sync {
            // Double-check cache key is still a string (defensive programming)
            guard validateCacheKey(validPath) else {
                logger.error("IconCacheService: Cache key validation failed for: '\(validPath)'")
                return getDefaultIcon()
            }

            if let cached = iconCache[validPath] {
                logger.debug("IconCacheService: Cache hit for path: '\(validPath)'")
                return cached
            }

            logger.debug("IconCacheService: Cache miss for path: '\(validPath)', loading icon")
            let icon = NSWorkspace.shared.icon(forFile: validPath)

            // Validate icon before caching
            guard validateIconForCaching(icon) else {
                logger.error("IconCacheService: Invalid icon returned for path: '\(validPath)'")
                return getDefaultIcon()
            }

            iconCache[validPath] = icon
            logger.debug("IconCacheService: Icon cached for path: '\(validPath)', cache size: \(iconCache.count)")
            return icon
        }
    }
    
    // ------------------------------
    // MARK: - Private Helper Methods
    // ------------------------------

    /// Validate and sanitize incoming path parameter
    private func validateAndSanitizePath(_ path: Any) -> String? {
        // Handle potential type confusion - ensure we have a string
        guard let stringPath = path as? String else {
            logger.error("IconCacheService: Path parameter is not a String, type: \(type(of: path))")
            return nil
        }

        // Ensure path is not empty
        guard !stringPath.isEmpty else {
            logger.debug("IconCacheService: Path is empty")
            return nil
        }

        // Additional safety check - ensure it's really a valid file path
        guard stringPath.isValidFilePath else {
            logger.debug("IconCacheService: Invalid file path: '\(stringPath)'")
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
        let entriesToPreload = min(entries.count, limit)
        logger.debug("IconCacheService: Starting preload for \(entriesToPreload) icons")

        iconLoadingQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            var loadedCount = 0
            for entry in entries.prefix(limit) {
                // Validate entry path before processing
                guard let validPath = self.validateAndSanitizePath(entry.fullPath) else {
                    self.logger.error("IconCacheService: Invalid path in FileEntry: '\(entry.fullPath)'")
                    continue
                }

                // Thread-safe cache check and update with enhanced error handling
                self.iconCacheQueue.sync {
                    // Validate cache state before access
                    guard self.validateCacheIntegrity() else {
                        self.logger.error("IconCacheService: Cache integrity check failed, clearing cache")
                        self.iconCache.removeAll()
                        return
                    }

                    if self.iconCache[validPath] == nil {
                        self.logger.debug("IconCacheService: Preloading icon for: '\(validPath)'")
                        let icon = NSWorkspace.shared.icon(forFile: validPath)

                        // Validate icon before caching
                        if self.validateIconForCaching(icon) {
                            self.iconCache[validPath] = icon
                            loadedCount += 1
                        } else {
                            self.logger.error("IconCacheService: Invalid icon for path: '\(validPath)'")
                        }
                    } else {
                        self.logger.debug("IconCacheService: Icon already cached for: '\(validPath)'")
                    }
                }
            }
            self.logger.debug("IconCacheService: Preload complete, loaded \(loadedCount) new icons, total cache size: \(self.iconCache.count)")
        }
    }

    /// Clear the icon cache with enhanced safety
    func clearCache() {
        logger.debug("IconCacheService: Clearing icon cache")
        iconCacheQueue.sync {
            let previousCount = iconCache.count
            iconCache.removeAll()
            logger.debug("IconCacheService: Cache cleared, removed \(previousCount) icons")
        }
    }

    /// Get cache statistics with integrity check
    func getCacheStats() -> (count: Int, memoryEstimate: String) {
        return iconCacheQueue.sync {
            // Validate cache integrity before reporting stats
            if !validateCacheIntegrity() {
                logger.error("IconCacheService: Cache integrity issue detected during stats request")
                iconCache.removeAll()
            }

            let count = iconCache.count
            let memoryEstimate = ByteCountFormatter.string(fromByteCount: Int64(count * 32 * 32 * 4), countStyle: .memory)
            logger.debug("IconCacheService: Cache stats - count: \(count), estimated memory: \(memoryEstimate)")
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
}

