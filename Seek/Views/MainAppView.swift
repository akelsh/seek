import SwiftUI

struct MainAppView: View {
    @State private var selectedView: MainViewType = .search
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var hasSearchResults = false
    @State private var refreshTrigger = false
    @State private var isRefreshing = false
    @State private var isTransitionComplete = false

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
                        SearchView(isSidebarVisible: columnVisibility != .detailOnly, hasSearchResults: $hasSearchResults, refreshTrigger: $refreshTrigger, isRefreshing: $isRefreshing)
                    case .settings:
                        SettingsView()
                    case .help:
                        HelpView()
                    }
                }
                .id(selectedView)
                .animation(isTransitionComplete ? .easeInOut(duration: 0.2) : nil, value: selectedView)
            }
        )
        .background(SeekTheme.appBackground)
        .toolbar {
            if selectedView == .search {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: {
                        isRefreshing = true
                        refreshTrigger.toggle()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!hasSearchResults || isRefreshing)

                    Button(action: {
                        // Download action
                    }) {
                        Image(systemName: "arrow.down.doc")
                    }
                    .disabled(!hasSearchResults)
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
        .onAppear {
            // Delay enabling internal animations to avoid conflicts with transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isTransitionComplete = true
            }
        }
    }
}



#Preview {
    MainAppView()
}
