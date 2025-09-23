import SwiftUI

struct SearchResultsList: View {
    let results: [FileEntry]
    let searchTime: TimeInterval
    let selectedIndex: Int?
    let searchViewModel: SearchViewModel
    let onItemSelected: (Int, FileEntry) -> Void

    var body: some View {
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
                                onItemSelected(index, result)
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
}

#Preview {
    SearchResultsList(
        results: [
            FileEntry(
                name: "Sample1.txt",
                fullPath: "/Users/test/Sample1.txt",
                isDirectory: false,
                fileExtension: "txt",
                size: 1024,
                dateModified: Date()
            ),
            FileEntry(
                name: "Sample2.txt",
                fullPath: "/Users/test/Sample2.txt",
                isDirectory: false,
                fileExtension: "txt",
                size: 2048,
                dateModified: Date().addingTimeInterval(-3600)
            )
        ],
        searchTime: 0.123,
        selectedIndex: 0,
        searchViewModel: SearchViewModel(),
        onItemSelected: { _, _ in }
    )
    .padding()
}