import Foundation
import Combine
import AppKit

@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Published Properties (only for UI binding)
    @Published var searchText = ""

    // MARK: - Callbacks (to avoid @Published rebuilding views)
    var onResultsChanged: (([FileEntry], TimeInterval, String?) -> Void)?

    // MARK: - Private Properties
    private let searchService = SearchService()
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let iconLoadingQueue = DispatchQueue(label: "com.seek.iconLoading", attributes: .concurrent)

    // Icon cache - not published to avoid view updates
    private var iconCache: [String: NSImage] = [:]
    private let iconCacheQueue = DispatchQueue(label: "com.seek.iconCache", attributes: .concurrent)

    // MARK: - Initialization
    init() {
        setupSearchTextObserver()
    }

    // MARK: - Public Methods
    func clearSearch() {
        searchText = ""
        // Notify with empty results
        onResultsChanged?([], 0, nil)
    }

    func icon(for path: String) -> NSImage {
        // Ensure path is a proper string to avoid NSNumber crashes
        guard !path.isEmpty else {
            return NSWorkspace.shared.icon(forFileType: "public.data")
        }

        let safePath = String(describing: path)

        // Additional safety check - ensure it's really a string
        guard safePath.isValidFilePath else {
            return NSWorkspace.shared.icon(forFileType: "public.data")
        }

        // Thread-safe cache access
        return iconCacheQueue.sync {
            if let cached = iconCache[safePath] {
                return cached
            }

            let icon = NSWorkspace.shared.icon(forFile: safePath)
            iconCache[safePath] = icon
            return icon
        }
    }

    // MARK: - Private Methods
    private func setupSearchTextObserver() {
        $searchText
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(query: searchText)
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) {
        // Cancel previous search
        searchTask?.cancel()

        // Clear results if query is empty
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onResultsChanged?([], 0, nil)
            return
        }

        executeSearch(query: query)
    }

    private func executeSearch(query: String) {
        searchTask = Task { [weak self] in
            guard let self = self else { return }

            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                let result = try await searchService.search(query: query, limit: 100)

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                let endTime = CFAbsoluteTimeGetCurrent()
                let searchTime = endTime - startTime

                await MainActor.run {
                    // Notify view with results via callback (not @Published)
                    self.onResultsChanged?(result.entries, searchTime, nil)
                }

                // Preload icons in background
                self.preloadIconsInBackground(for: result.entries)

            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                let endTime = CFAbsoluteTimeGetCurrent()
                let searchTime = endTime - startTime

                await MainActor.run {
                    // Notify view with error via callback
                    self.onResultsChanged?([], searchTime, "Search failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func preloadIconsInBackground(for entries: [FileEntry]) {
        iconLoadingQueue.async { [weak self] in
            for entry in entries.prefix(50) { // Limit to first 50 for performance
                guard let self = self else { break }

                // Thread-safe cache check and update
                self.iconCacheQueue.sync {
                    if self.iconCache[entry.fullPath] == nil {
                        let icon = NSWorkspace.shared.icon(forFile: entry.fullPath)
                        self.iconCache[entry.fullPath] = icon
                    }
                }
            }
        }
    }
}

// MARK: - String Extension for Path Validation
private extension String {
    var isValidFilePath: Bool {
        // Basic validation to ensure it's a valid file path string
        return !isEmpty &&
               !contains("\0") &&
               (hasPrefix("/") || hasPrefix("~")) &&
               !hasPrefix("0x") // Avoid hex addresses that might be passed accidentally
    }
}
