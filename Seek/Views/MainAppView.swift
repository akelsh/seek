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
                        SearchView(isSidebarVisible: columnVisibility != .detailOnly)
                    case .settings:
                        SettingsView()
                    case .help:
                        HelpView()
                    }
                }
                .id(selectedView)
                .animation(.easeInOut(duration: 0.2), value: selectedView)
            }
        )
        .background(SeekTheme.appBackground)
        .toolbar {
            if selectedView == .search {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: {
                        // Refresh action - could trigger refresh via notification
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }

                    Button(action: {
                        // Share action
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                ToolbarItem {
                    Spacer()
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        // Add action
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
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
