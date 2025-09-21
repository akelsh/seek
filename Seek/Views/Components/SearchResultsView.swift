import SwiftUI
import AppKit

// MARK: - Main Search View
struct SearchResultsView: View {
    let isSidebarVisible: Bool
    @StateObject private var searchViewModel = SearchViewModel()
    @FocusState private var searchFieldFocused: Bool
    @State private var selectedIndex: Int?
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background content
            searchContent
            
            // Floating search bar
            floatingSearchBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
        .navigationTitle("")
        .onAppear {
            searchFieldFocused = true
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
    
    // MARK: - View Components
    private var floatingSearchBar: some View {
        VStack {
            SearchBar(searchText: $searchViewModel.searchText, isFocused: $searchFieldFocused)
                .padding(.horizontal)
                .padding(.top, isSidebarVisible ? 16 : 56)
            Spacer()
        }
    }
    
    @ViewBuilder
    private var searchContent: some View {
        switch searchViewModel.state {
        case .idle:
            EmptyStateView()
        case .searching:
            // Keep showing previous results while searching
            if !searchViewModel.searchResults.isEmpty {
                ResultsListView(
                    results: searchViewModel.searchResults,
                    resultCount: searchViewModel.resultCount,
                    searchTime: searchViewModel.searchTime,
                    isSidebarVisible: isSidebarVisible,
                    selectedIndex: $selectedIndex,
                    searchViewModel: searchViewModel
                )
            } else {
                EmptyStateView()
            }
        case .results(let results) where results.entries.isEmpty:
            NoResultsView(searchTime: results.searchTime)
        case .results(let results):
            ResultsListView(
                results: results.entries,
                resultCount: results.count,
                searchTime: results.searchTime,
                isSidebarVisible: isSidebarVisible,
                selectedIndex: $selectedIndex,
                searchViewModel: searchViewModel
            )
        case .error(let message):
            ErrorStateView(message: message)
        }
    }
    
    // MARK: - Actions
    private func navigateResults(direction: Int) {
        let count = searchViewModel.searchResults.count
        guard count > 0 else { return }
        
        if let current = selectedIndex {
            selectedIndex = min(max(0, current + direction), count - 1)
        } else {
            selectedIndex = direction > 0 ? 0 : count - 1
        }
    }
    
    private func openSelectedFile() {
        if let index = selectedIndex,
           index < searchViewModel.searchResults.count {
            openFile(searchViewModel.searchResults[index])
        }
    }
    
    private func openFile(_ entry: FileEntry) {
        NSWorkspace.shared.open(URL(fileURLWithPath: entry.fullPath))
    }
}

// MARK: - Search Bar Component
struct SearchBar: View {
    @Binding var searchText: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack(spacing: SeekTheme.spacingMedium) {
            searchIcon
            searchTextField
            clearButton
        }
        .padding(.horizontal, SeekTheme.spacingLarge)
        .padding(.vertical, SeekTheme.spacingMedium)
        .background(searchBarBackground)
    }
    
    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .foregroundColor(SeekTheme.appTextSecondary)
            .font(.system(size: 16, weight: .medium))
    }
    
    private var searchTextField: some View {
        TextField("Search files...", text: $searchText)
            .font(.system(size: 15))
            .foregroundColor(SeekTheme.appTextPrimary)
            .textFieldStyle(PlainTextFieldStyle())
            .focused(isFocused)
    }
    
    @ViewBuilder
    private var clearButton: some View {
        if !searchText.isEmpty {
            Button(action: { searchText = "" }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(SeekTheme.appTextSecondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    @ViewBuilder
    private var searchBarBackground: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .regular.tint(SeekTheme.appElevated.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: SeekTheme.cornerRadiusLarge)
                )
        } else {
            RoundedRectangle(cornerRadius: SeekTheme.cornerRadiusLarge)
                .fill(.thinMaterial)
        }
    }
}

// MARK: - State Views
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: SeekTheme.spacingLarge) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(SeekTheme.appTextTertiary)
            
            VStack(spacing: SeekTheme.spacingSmall) {
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
}

struct NoResultsView: View {
    let searchTime: TimeInterval
    
    var body: some View {
        VStack(spacing: SeekTheme.spacingMedium) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(SeekTheme.appTextTertiary)
            
            Text("No files found")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(SeekTheme.appTextSecondary)
            
            Text("Searched in \(String(format: "%.2f", searchTime))s")
                .font(.system(size: 12))
                .foregroundColor(SeekTheme.appTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: SeekTheme.spacingMedium) {
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
}

// MARK: - Results List
struct ResultsListView: View {
    let results: [FileEntry]
    let resultCount: Int
    let searchTime: TimeInterval
    let isSidebarVisible: Bool
    @Binding var selectedIndex: Int?
    @ObservedObject var searchViewModel: SearchViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    resultsHeader
                    resultsList
                }
                .padding(.top, topPadding)
            }
            .scrollIndicators(.visible)
            .onChange(of: selectedIndex) { _, newIndex in
                scrollToSelectedItem(newIndex, proxy: proxy)
            }
        }
    }
    
    private var topPadding: CGFloat {
        isSidebarVisible ? 80 : 120
    }
    
    private var resultsHeader: some View {
        ResultsHeader(count: resultCount, searchTime: searchTime)
            .padding(.horizontal)
            .padding(.bottom, SeekTheme.spacingSmall)
    }
    
    private var resultsList: some View {
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
            .id(index)
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }
    
    private func scrollToSelectedItem(_ index: Int?, proxy: ScrollViewProxy) {
        if let index = index {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(index, anchor: .center)
            }
        }
    }
}

struct ResultsHeader: View {
    let count: Int
    let searchTime: TimeInterval
    
    var body: some View {
        HStack {
            resultCountText
            separatorDot
            searchTimeText
            Spacer()
        }
    }
    
    private var resultCountText: some View {
        Text("\(count) result\(count == 1 ? "" : "s")")
            .font(.caption)
            .foregroundColor(SeekTheme.appTextSecondary)
    }
    
    private var separatorDot: some View {
        Text("•")
            .font(.caption)
            .foregroundColor(SeekTheme.appTextTertiary)
    }
    
    private var searchTimeText: some View {
        Text("\(String(format: "%.2f", searchTime))s")
            .font(.caption)
            .foregroundColor(SeekTheme.appTextTertiary)
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
            HStack(spacing: SeekTheme.spacingMedium) {
                fileIcon
                fileInfo
                Spacer()
                fileMetadata
            }
            .padding(.horizontal, SeekTheme.spacingMedium)
            .padding(.vertical, SeekTheme.spacingSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(backgroundColor)
        .cornerRadius(SeekTheme.cornerRadiusMedium)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - View Components
    private var fileIcon: some View {
        Image(nsImage: searchViewModel.icon(for: fileEntry.fullPath))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
    }
    
    private var fileInfo: some View {
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
    }
    
    private var fileMetadata: some View {
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
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Open") {
            action()
        }
        
        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(fileEntry.fullPath, inFileViewerRootedAtPath: "")
        }
        
        Divider()
        
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(fileEntry.fullPath, forType: .string)
        }
    }
    
    // MARK: - Computed Properties
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