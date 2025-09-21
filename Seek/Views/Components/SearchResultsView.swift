import SwiftUI
import AppKit

struct SearchResultsView: View {
    let isSidebarVisible: Bool
    @StateObject private var searchViewModel = SearchViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            // Background content
            SearchResultsList(viewModel: searchViewModel, isSidebarVisible: isSidebarVisible)

            // Floating search bar
            VStack {
                SearchBar(searchText: $searchViewModel.searchText)
                    .padding(.horizontal)
                    .padding(.top, isSidebarVisible ? 16 : 56)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle("")
    }
}

struct SearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: SeekTheme.spacingMedium) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SeekTheme.appTextSecondary)
                .font(.system(size: 16, weight: .medium))

            TextField("Search files...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(SeekTheme.appTextPrimary)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, SeekTheme.spacingLarge)
        .padding(.vertical, SeekTheme.spacingMedium)
        .background {
            if #available(macOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular.tint(SeekTheme.appElevated.opacity(0.1)), in: RoundedRectangle(cornerRadius: SeekTheme.cornerRadiusLarge))
            } else {
                RoundedRectangle(cornerRadius: SeekTheme.cornerRadiusLarge)
                    .fill(.thinMaterial)
            }
        }
    }
}

struct SearchResultsList: View {
    @ObservedObject var viewModel: SearchViewModel
    let isSidebarVisible: Bool

    var body: some View {
        if let errorMessage = viewModel.errorMessage {
            VStack {
                Spacer()
                Text(errorMessage)
                    .foregroundColor(SeekTheme.appTextSecondary)
                    .font(.system(size: 14))
                Spacer()
            }
        } else if viewModel.searchText.isEmpty {
            VStack {
                Spacer()
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
                Spacer()
            }
        } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty && !viewModel.isLoading && viewModel.resultCount == 0 && viewModel.searchTime > 0 {
            VStack {
                Spacer()
                Text("No files found")
                    .foregroundColor(SeekTheme.appTextSecondary)
                    .font(.system(size: 14))
                Spacer()
            }
        } else if !viewModel.searchResults.isEmpty {
            ScrollView {
                LazyVStack(spacing: SeekTheme.spacingSmall) {
                    // Result count header that scrolls with content
                    HStack {
                        Text("\(viewModel.resultCount) results")
                            .font(.caption)
                            .foregroundColor(SeekTheme.appTextSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)

                    ForEach(viewModel.searchResults) { result in
                        SearchResultItem(fileEntry: result, searchViewModel: viewModel)
                    }
                }
                .padding()
                .padding(.top, isSidebarVisible ? 60 : 100) // Add top padding so first result isn't hidden behind search bar
            }
            .clipped()
            .mask(
                Rectangle()
                    .padding(.top, isSidebarVisible ? 0 : 40) // Items clip out based on sidebar visibility
            )
        }
    }
}

struct SearchResultItem: View {
    let fileEntry: FileEntry
    @ObservedObject var searchViewModel: SearchViewModel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: SeekTheme.spacingMedium) {
            // File icon
            SystemFileIcon(filePath: fileEntry.fullPath, cachedIcon: searchViewModel.iconCache[fileEntry.fullPath])
                .frame(width: 32, height: 32)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(fileEntry.name)
                    .foregroundColor(SeekTheme.appTextPrimary)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Text(fileEntry.fullPath)
                    .foregroundColor(SeekTheme.appTextSecondary)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }

            Spacer()

            // File size and date
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
        .padding(.horizontal, SeekTheme.spacingMedium)
        .padding(.vertical, SeekTheme.spacingSmall)
        .background(isHovered ? SeekTheme.appHover : Color.clear)
        .cornerRadius(SeekTheme.cornerRadiusMedium)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            // TODO: Handle file selection/opening
            print("Selected file: \(fileEntry.name)")
        }
    }


    private var relativeDateString: String {
        let date = fileEntry.dateModifiedAsDate
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SystemFileIcon: View {
    let filePath: String
    let cachedIcon: NSImage?

    var body: some View {
        Group {
            if let icon = cachedIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "doc")
                    .foregroundColor(SeekTheme.appTextSecondary)
            }
        }
    }
}
