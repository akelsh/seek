import Foundation

enum MainViewType: String, CaseIterable {
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