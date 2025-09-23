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
    private let iconCacheService = IconCacheService.shared
    private let logger = LoggingService.shared

    // MARK: - Initialization
    init() {
        logger.debug("SearchViewModel: Initializing")
        setupSearchTextObserver()
        logger.debug("SearchViewModel: Initialization complete")
    }

    // MARK: - Public Methods
    func clearSearch() {
        logger.debug("SearchViewModel: Clearing search")
        searchText = ""
        // Notify with empty results
        onResultsChanged?([], 0, nil)
        logger.debug("SearchViewModel: Search cleared, notified with empty results")
    }

    func reperformSearch() {
        logger.debug("SearchViewModel: Reperforming search with current query: '\(searchText)'")
        guard !searchText.isEmpty else {
            logger.debug("SearchViewModel: Cannot refresh - search text is empty")
            return
        }
        performSearch(query: searchText)
    }

    func icon(for path: String) -> NSImage {
        return iconCacheService.icon(for: path)
    }

    // MARK: - Private Methods
    private func setupSearchTextObserver() {
        logger.debug("SearchViewModel: Setting up search text observer with 100ms debounce")
        $searchText
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.logger.debug("SearchViewModel: Search text changed to: '\(searchText)'")
                self?.performSearch(query: searchText)
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) {
        logger.debug("SearchViewModel: performSearch called with query: '\(query)'")

        // Cancel previous search
        if searchTask != nil {
            logger.debug("SearchViewModel: Cancelling previous search task")
            searchTask?.cancel()
        }

        // Clear results if query is empty
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("SearchViewModel: Query is empty, clearing results")
            onResultsChanged?([], 0, nil)
            return
        }

        logger.debug("SearchViewModel: Executing search for non-empty query")
        executeSearch(query: query)
    }

    private func executeSearch(query: String) {
        logger.debug("SearchViewModel: Creating new search task for query: '\(query)'")
        searchTask = Task { [weak self] in
            guard let self = self else {
                self?.logger.debug("SearchViewModel: Self is nil, exiting search task")
                return
            }

            let startTime = CFAbsoluteTimeGetCurrent()
            logger.debug("SearchViewModel: Starting search at time: \(startTime)")

            do {
                logger.debug("SearchViewModel: Calling searchService.search with limit: 100")
                let result = try await searchService.search(query: query, limit: 100)

                // Check if task was cancelled
                guard !Task.isCancelled else {
                    logger.debug("SearchViewModel: Task was cancelled, exiting")
                    return
                }

                let endTime = CFAbsoluteTimeGetCurrent()
                let searchTime = endTime - startTime
                logger.debug("SearchViewModel: Search completed in \(searchTime)s, found \(result.entries.count) results")

                await MainActor.run {
                    logger.debug("SearchViewModel: Notifying view with \(result.entries.count) results")
                    // Notify view with results via callback (not @Published)
                    self.onResultsChanged?(result.entries, searchTime, nil)
                }

                logger.debug("SearchViewModel: Preloading icons for \(result.entries.count) entries")
                // Preload icons in background
                self.iconCacheService.preloadIcons(for: result.entries)

            } catch {
                logger.error("SearchViewModel: Search failed with error: \(error)")
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    logger.debug("SearchViewModel: Task was cancelled after error, exiting")
                    return
                }

                let endTime = CFAbsoluteTimeGetCurrent()
                let searchTime = endTime - startTime

                await MainActor.run {
                    logger.debug("SearchViewModel: Notifying view with error message")
                    // Notify view with error via callback
                    self.onResultsChanged?([], searchTime, "Search failed: \(error.localizedDescription)")
                }
            }
        }
    }

}
