import Foundation
import Combine
import AppKit

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [FileEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchTime: TimeInterval = 0
    @Published var resultCount: Int = 0
    @Published var iconCache: [String: NSImage] = [:]

    private let searchService = SearchService()
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Debounce search text changes
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
            searchResults = []
            isLoading = false
            errorMessage = nil
            searchTime = 0
            resultCount = 0
            return
        }

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

    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
        isLoading = false
        iconCache = [:]
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