import SwiftUI

struct AppToolbar: ToolbarContent {
    let onSearch: () -> Void
    let onSettings: () -> Void
    let onHelp: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            ToolbarButton(icon: "magnifyingglass", action: onSearch)
            ToolbarButton(icon: "questionmark", action: onHelp)
            ToolbarButton(icon: "gear", action: onSettings)
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(SeekTheme.appTextPrimary)
        }
    }
}