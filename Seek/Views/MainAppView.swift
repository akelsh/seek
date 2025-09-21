import SwiftUI

struct MainAppView: View {
    @State private var selectedView: MainView = .search
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility,
            sidebar: {
                Sidebar(selectedView: $selectedView)
                    .navigationSplitViewColumnWidth(
                        min: 180,
                        ideal: 220,
                        max: 220
                    )
            },
            detail: {
                Group {
                    switch selectedView {
                    case .search:
                        SearchView(
                            isSidebarVisible: columnVisibility != .detailOnly
                        )
                    case .settings:
                        SettingsView()
                    case .help:
                        HelpView()
                    }
                }
            }
        )
        .background(SeekTheme.appBackground)
    }
}

enum MainView: String, CaseIterable {
    case search = "Search"
    case settings = "Settings"
    case help = "Help"

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .settings: return "gear"
        case .help: return "questionmark.circle"
        }
    }
}


#Preview {
    MainAppView()
}
