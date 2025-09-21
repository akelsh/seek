import SwiftUI

struct SearchView: View {
    let isSidebarVisible: Bool

    var body: some View {
        SearchResultsView(isSidebarVisible: isSidebarVisible)
    }
}

#Preview {
    SearchView(isSidebarVisible: true)
}
