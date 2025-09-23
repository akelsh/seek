import SwiftUI
import AppKit

struct SearchView: View {
    let isSidebarVisible: Bool
    @StateObject private var searchViewModel = SearchViewModel()

    // Local state - independent of search results
    @State private var results: [FileEntry] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTime: TimeInterval = 0
    @State private var selectedIndex: Int?

    // Focus management
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search bar - always present, never rebuilds
            searchBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            // Results area - stable structure, content changes
            resultsArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
        .onAppear {
            if searchViewModel.onResultsChanged == nil {
                setupSearchCallback()
            }
            isSearchFocused = true
        }
        .onKeyPress(.upArrow) {
            navigateResults(direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateResults(direction: 1)
            return .handled
        }
        .onKeyPress(.return) {
            openSelectedFile()
            return .handled
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SeekTheme.appTextSecondary)
                .font(.system(size: 16, weight: .medium))

            TextField("Search files...", text: $searchViewModel.searchText)
                .font(.system(size: 15))
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isSearchFocused)

            if !searchViewModel.searchText.isEmpty {
                Button(action: { searchViewModel.clearSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(SeekTheme.appTextSecondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(searchBarBackground)
    }

    @ViewBuilder
    private var searchBarBackground: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .regular.tint(SeekTheme.appElevated.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 32)
                )
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
        }
    }

    // MARK: - Results Area
    @ViewBuilder
    private var resultsArea: some View {
        if let errorMessage = errorMessage {
            errorView(message: errorMessage)
        } else if results.isEmpty {
            emptyStateView
        } else {
            resultsList
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: searchViewModel.searchText.isEmpty ? "magnifyingglass" : "doc.text.magnifyingglass")
                .font(.system(size: searchViewModel.searchText.isEmpty ? 48 : 36, weight: .light))
                .foregroundColor(SeekTheme.appTextTertiary)

            VStack(spacing: 8) {
                Text(searchViewModel.searchText.isEmpty ? "Start searching" : "No files found")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(SeekTheme.appTextSecondary)

                Text(searchViewModel.searchText.isEmpty
                     ? "Type in the search field to find files and folders"
                     : searchTime > 0 ? "Searched in \(String(format: "%.2f", searchTime))s" : "")
                    .font(.system(size: 14))
                    .foregroundColor(SeekTheme.appTextTertiary)
                    .multilineTextAlignment(.center)
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    // Results header
                    HStack {
                        Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(SeekTheme.appTextSecondary)

                        Text("•")
                            .font(.caption)
                            .foregroundColor(SeekTheme.appTextTertiary)

                        Text("\(String(format: "%.2f", searchTime))s")
                            .font(.caption)
                            .foregroundColor(SeekTheme.appTextTertiary)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    // Results list
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        SearchResultItem(
                            fileEntry: result,
                            searchViewModel: searchViewModel,
                            isSelected: selectedIndex == index,
                            action: {
                                selectedIndex = index
                                NSWorkspace.shared.open(URL(fileURLWithPath: result.fullPath))
                            }
                        )
                        .id(result.id) // Use the file ID for scrolling
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
            }
            .scrollIndicators(.visible)
            .onChange(of: selectedIndex) { _, newIndex in
                if let newIndex = newIndex, newIndex < results.count {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(results[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Setup and Actions
    private func setupSearchCallback() {
        searchViewModel.onResultsChanged = { results, searchTime, error in
            // Use async dispatch to avoid "Publishing changes from within view updates" error
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.results = results
                    self.searchTime = searchTime
                    self.errorMessage = error
                }

                // Maintain focus after search completes
                if !self.isSearchFocused {
                    self.isSearchFocused = true
                }
            }
        }
    }

    private func navigateResults(direction: Int) {
        guard !results.isEmpty else { return }

        if let current = selectedIndex {
            selectedIndex = min(max(0, current + direction), results.count - 1)
        } else {
            selectedIndex = direction > 0 ? 0 : results.count - 1
        }
    }

    private func openSelectedFile() {
        if let index = selectedIndex, index < results.count {
            NSWorkspace.shared.open(URL(fileURLWithPath: results[index].fullPath))
        }
    }
}

// MARK: - Search Result Item
struct SearchResultItem: View {
    let fileEntry: FileEntry
    @ObservedObject var searchViewModel: SearchViewModel
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(nsImage: searchViewModel.icon(for: fileEntry.fullPath))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileEntry.name)
                        .foregroundColor(SeekTheme.appTextPrimary)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    Text(fileEntry.fullPath)
                        .foregroundColor(SeekTheme.appTextSecondary)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let formattedSize = fileEntry.formattedSize {
                        Text(formattedSize)
                            .foregroundColor(SeekTheme.appTextTertiary)
                            .font(.system(size: 11))
                    }

                    Text(relativeDateString)
                        .foregroundColor(SeekTheme.appTextTertiary)
                        .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(backgroundColor)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Open") { action() }
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(fileEntry.fullPath, inFileViewerRootedAtPath: "")
            }
            Divider()
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fileEntry.fullPath, forType: .string)
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return SeekTheme.appSelection
        } else if isHovered {
            return SeekTheme.appHover
        }
        return Color.clear
    }

    private var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: fileEntry.dateModifiedAsDate, relativeTo: Date())
    }
}

#Preview {
    SearchView(isSidebarVisible: true)
}
