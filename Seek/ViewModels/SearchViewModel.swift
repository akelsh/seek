import Foundation
import Combine
import AppKit

@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchText = ""
    @Published var searchResults: [FileEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchTime: TimeInterval = 0
    @Published var resultCount: Int = 0
    @Published var iconCache: [String: NSImage] = [:]
    
    // MARK: - Private Properties
    private let searchService = SearchService()
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties for View Compatibility
    var state: SearchState {
        if let error = errorMessage {
            return .error(error)
        } else if isLoading {
            return .searching
        } else if searchText.isEmpty {
            return .idle
        } else if !searchResults.isEmpty || searchTime > 0 {
            return .results(SearchResults(
                entries: searchResults,
                searchTime: searchTime
            ))
        }
        return .idle
    }
    
    // MARK: - Types
    enum SearchState {
        case idle
        case searching
        case results(SearchResults)
        case error(String)
    }
    
    struct SearchResults {
        let entries: [FileEntry]
        let searchTime: TimeInterval
        var count: Int { entries.count }
    }
    
    // MARK: - Initialization
    init() {
        setupSearchTextObserver()
    }
    
    // MARK: - Public Methods
    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
        isLoading = false
        iconCache = [:]
    }
    
    func icon(for path: String) -> NSImage {
        if let cached = iconCache[path] {
            return cached
        }
        
        // Don't update cache during view updates - just return the icon
        let icon = NSWorkspace.shared.icon(forFile: path)
        
        // Schedule cache update for next run loop
        Task { @MainActor in
            iconCache[path] = icon
        }
        
        return icon
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
            clearSearchResults()
            return
        }
        
        executeSearch(query: query)
    }
    
    private func clearSearchResults() {
        searchResults = []
        isLoading = false
        errorMessage = nil
        searchTime = 0
        resultCount = 0
    }
    
    private func executeSearch(query: String) {
        isLoading = true
        errorMessage = nil
        
        searchTask = Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                let result = try await searchService.search(query: query, limit: 100)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                let endTime = CFAbsoluteTimeGetCurrent()
                searchTime = endTime - startTime
                searchResults = result.entries
                resultCount = result.entries.count
                isLoading = false
                
                // Preload icons for smooth scrolling
                preloadIcons(for: result.entries)
                
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                let endTime = CFAbsoluteTimeGetCurrent()
                searchTime = endTime - startTime
                errorMessage = "Search failed: \(error.localizedDescription)"
                searchResults = []
                resultCount = 0
                isLoading = false
            }
        }
    }
    
    private func preloadIcons(for entries: [FileEntry]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for entry in entries {
                    group.addTask {
                        let icon = NSWorkspace.shared.icon(forFile: entry.fullPath)
                        await MainActor.run {
                            self.iconCache[entry.fullPath] = icon
                        }
                    }
                }
            }
        }
    }
}