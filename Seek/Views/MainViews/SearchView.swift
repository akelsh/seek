import SwiftUI
import AppKit

struct SearchView: View {
    let isSidebarVisible: Bool
    @Binding var hasSearchResults: Bool
    @Binding var refreshTrigger: Bool
    @Binding var isRefreshing: Bool
    @StateObject private var searchViewModel = SearchViewModel()

    // Local state - independent of search results
    @State private var results: [FileEntry] = []
    @State private var errorMessage: String?
    @State private var searchTime: TimeInterval = 0
    @State private var selectedIndex: Int?
    @State private var refreshStartTime: Date?

    // Focus management
    @FocusState private var isSearchFocused: Bool

    private let logger = LoggingService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Search bar - always present, never rebuilds
            SearchBar(searchViewModel: searchViewModel, isSearchFocused: $isSearchFocused)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)

            // Results area - stable structure, content changes
            resultsArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            logger.debug("SearchView: View appeared")
            if searchViewModel.onResultsChanged == nil {
                logger.debug("SearchView: Setting up search callback")
                setupSearchCallback()
            }
            isSearchFocused = true
            logger.debug("SearchView: Search field focused")
        }
        .onChange(of: searchViewModel.searchText) { _, newValue in
            if newValue.isEmpty {
                logger.debug("SearchView: Search text cleared, clearing results")
                withAnimation(.easeInOut(duration: 0.2)) {
                    results = []
                    hasSearchResults = false
                }
            }
        }
        .onChange(of: refreshTrigger) { _, _ in
            logger.debug("SearchView: Refresh triggered, reperforming search")
            refreshStartTime = Date()
            searchViewModel.reperformSearch()
        }
        .onKeyPress(.upArrow) {
            logger.debug("SearchView: Up arrow pressed")
            navigateResults(direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            logger.debug("SearchView: Down arrow pressed")
            navigateResults(direction: 1)
            return .handled
        }
        .onKeyPress(.return) {
            logger.debug("SearchView: Return key pressed, opening selected file")
            openSelectedFile()
            return .handled
        }
    }


    // MARK: - Results Area
    @ViewBuilder
    private var resultsArea: some View {
        if isRefreshing {
            refreshingView
        } else if let errorMessage = errorMessage {
            errorView(message: errorMessage)
        } else if !hasSearchResults {
            // Haven't received any search results yet
            emptyStateView
        } else if results.isEmpty {
            // Received search results but they're empty
            noResultsView
        } else {
            // Have results to display
            resultsList
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(SeekTheme.appTextTertiary)

            VStack(spacing: 8) {
                Text("Start searching")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(SeekTheme.appTextSecondary)

                Text("Type in the search field to find files and folders")
                    .font(.system(size: 14))
                    .foregroundColor(SeekTheme.appTextTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(SeekTheme.appTextTertiary)

            VStack(spacing: 8) {
                Text("No files found")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(SeekTheme.appTextSecondary)

                Text("There doesn't appear to be any files matching your search")
                    .font(.system(size: 14))
                    .foregroundColor(SeekTheme.appTextTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var refreshingView: some View {
        VStack(spacing: 24) {
            // Custom loading spinner
            SeekLoadingSpinner()
                .frame(width: 48, height: 48)

            VStack(spacing: 8) {
                Text("Refreshing...")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(SeekTheme.appTextSecondary)

                Text("Please wait a moment")
                    .font(.system(size: 14))
                    .foregroundColor(SeekTheme.appTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(SeekTheme.appError)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(SeekTheme.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        SearchResultsList(
            results: results,
            searchTime: searchTime,
            selectedIndex: selectedIndex,
            searchViewModel: searchViewModel,
            onItemSelected: { index, result in
                logger.debug("SearchView: Item selected at index \(index): '\(result.fullPath)'")
                selectedIndex = index
                let url = URL(fileURLWithPath: result.fullPath)
                logger.debug("SearchView: Opening URL: \(url)")
                NSWorkspace.shared.open(url)
            }
        )
    }

    // MARK: - Setup and Actions
    private func setupSearchCallback() {
        logger.debug("SearchView: Setting up search callback")
        searchViewModel.onResultsChanged = { results, searchTime, error in
            logger.debug("SearchView: Received search results callback - \(results.count) results, time: \(searchTime)s, error: \(error ?? "none")")

            // Use async dispatch to avoid "Publishing changes from within view updates" error
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.logger.debug("SearchView: Updating UI with new results")
                    self.results = results
                    self.searchTime = searchTime
                    self.errorMessage = error

                    // Mark that we've received search results
                    if !self.searchViewModel.searchText.isEmpty {
                        self.hasSearchResults = true
                        self.logger.debug("SearchView: Search results received, hasSearchResults set to true")
                    }

                    // Stop refresh animation if it was a refresh
                    if self.isRefreshing {
                        // Calculate how long the refresh has been showing
                        let elapsedTime = self.refreshStartTime?.timeIntervalSinceNow ?? 0
                        let minimumDisplayTime: TimeInterval = 1.2  // Show for at least 1.2 seconds
                        let remainingTime = max(0, minimumDisplayTime + elapsedTime)

                        self.logger.debug("SearchView: Refresh complete, will hide after \(remainingTime)s")

                        // Delay hiding if needed to meet minimum display time
                        DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                self.isRefreshing = false
                            }
                        }
                    }
                }

                // Maintain focus after search completes
                if !self.isSearchFocused {
                    self.logger.debug("SearchView: Restoring search focus")
                    self.isSearchFocused = true
                }
            }
        }
    }

    private func navigateResults(direction: Int) {
        guard !results.isEmpty else {
            logger.debug("SearchView: Cannot navigate, results are empty")
            return
        }

        if let current = selectedIndex {
            let newIndex = min(max(0, current + direction), results.count - 1)
            logger.debug("SearchView: Navigating from index \(current) to \(newIndex)")
            selectedIndex = newIndex
        } else {
            let newIndex = direction > 0 ? 0 : results.count - 1
            logger.debug("SearchView: Setting initial selection to index \(newIndex)")
            selectedIndex = newIndex
        }
    }

    private func openSelectedFile() {
        if let index = selectedIndex, index < results.count {
            let path = results[index].fullPath
            logger.debug("SearchView: Opening selected file at index \(index): '\(path)'")
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else {
            logger.debug("SearchView: No file selected to open")
        }
    }
}


#Preview {
    SearchView(isSidebarVisible: true, hasSearchResults: .constant(false), refreshTrigger: .constant(false), isRefreshing: .constant(false))
}
