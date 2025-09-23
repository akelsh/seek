import SwiftUI

struct SearchBar: View {
    @ObservedObject var searchViewModel: SearchViewModel
    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
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
}

#Preview {
    struct PreviewWrapper: View {
        @FocusState private var isSearchFocused: Bool

        var body: some View {
            SearchBar(
                searchViewModel: SearchViewModel(),
                isSearchFocused: $isSearchFocused
            )
            .padding()
        }
    }

    return PreviewWrapper()
}