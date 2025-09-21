import SwiftUI

struct Sidebar: View {
    @Binding var selectedView: MainView
    @State private var quickAccessExpanded = false
    @State private var locationsExpanded = true
    @State private var filterByExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: SeekTheme.spacingLarge) {
                // Quick Access Section
                CollapsibleSection(
                    title: "Quick Access",
                    isExpanded: $quickAccessExpanded,
                    content: {
                        VStack(spacing: SeekTheme.spacingXSmall) {
                            SidebarItem(icon: "clock", title: "Recent Searches", badge: "5") {
                                selectedView = .search
                            }
                            SidebarItem(icon: "star", title: "Saved Searches") {
                                selectedView = .search
                            }
                        }
                    }
                )

                // Locations Section
                CollapsibleSection(
                    title: "Locations",
                    isExpanded: $locationsExpanded,
                    content: {
                        VStack(spacing: SeekTheme.spacingXSmall) {
                            SidebarItem(icon: "externaldrive", title: "All Drives") {
                                selectedView = .search
                            }
                            SidebarItem(icon: "folder", title: "Documents") {
                                selectedView = .search
                            }
                            SidebarItem(icon: "arrow.down.circle", title: "Downloads") {
                                selectedView = .search
                            }
                            SidebarItem(icon: "desktopcomputer", title: "Desktop") {
                                selectedView = .search
                            }
                            SidebarItem(icon: "app", title: "Applications") {
                                selectedView = .search
                            }
                        }
                    }
                )

                // Filter By Section
                CollapsibleSection(
                    title: "Filter By",
                    isExpanded: $filterByExpanded,
                    content: {
                        VStack(alignment: .leading, spacing: SeekTheme.spacingMedium) {
                            // Modified subsection
                            VStack(alignment: .leading, spacing: SeekTheme.spacingXSmall) {
                                Text("Modified")
                                    .font(.caption)
                                    .foregroundColor(SeekTheme.appTextSecondary)
                                    .padding(.leading, SeekTheme.spacingSmall)

                                SidebarItem(icon: "clock", title: "Today") {
                                    selectedView = .search
                                }
                                SidebarItem(icon: "calendar", title: "This Week") {
                                    selectedView = .search
                                }
                                SidebarItem(icon: "calendar", title: "This Month") {
                                    selectedView = .search
                                }
                            }

                            // Type subsection
                            VStack(alignment: .leading, spacing: SeekTheme.spacingXSmall) {
                                Text("Type")
                                    .font(.caption)
                                    .foregroundColor(SeekTheme.appTextSecondary)
                                    .padding(.leading, SeekTheme.spacingSmall)

                                SidebarItem(icon: "doc.text", title: "Documents") {
                                    selectedView = .search
                                }
                                SidebarItem(icon: "photo", title: "Images") {
                                    selectedView = .search
                                }
                                SidebarItem(icon: "video", title: "Videos") {
                                    selectedView = .search
                                }
                                SidebarItem(icon: "chevron.left.forwardslash.chevron.right", title: "Code") {
                                    selectedView = .search
                                }
                                SidebarItem(icon: "doc.zipper", title: "Archives") {
                                    selectedView = .search
                                }
                            }

                            // Size subsection
                            VStack(alignment: .leading, spacing: SeekTheme.spacingXSmall) {
                                Text("Size")
                                    .font(.caption)
                                    .foregroundColor(SeekTheme.appTextSecondary)
                                    .padding(.leading, SeekTheme.spacingSmall)

                                SidebarItem(icon: "square.stack.3d.up", title: "Large", subtitle: ">1GB") {
                                    selectedView = .search
                                }
                                SidebarItem(icon: "square.stack", title: "Medium", subtitle: "10MB-1GB") {
                                    selectedView = .search
                                }
                                SidebarItem(icon: "square", title: "Small", subtitle: "<10MB") {
                                    selectedView = .search
                                }
                            }
                        }
                    }
                )
                }
                .padding(.vertical, SeekTheme.spacingMedium)
            }

            // Fixed navigation section at bottom
            VStack(spacing: 0) {
                Divider()
                    .background(SeekTheme.appSeparator)

                VStack(spacing: SeekTheme.spacingXSmall) {
                    NavigationButton(
                        icon: "magnifyingglass",
                        title: "Search",
                        isSelected: selectedView == .search,
                        action: {
                            selectedView = .search
                        }
                    )

                    NavigationButton(
                        icon: "gear",
                        title: "Settings",
                        isSelected: selectedView == .settings,
                        action: {
                            selectedView = selectedView == .settings ? .search : .settings
                        }
                    )

                    NavigationButton(
                        icon: "questionmark.circle",
                        title: "Help",
                        isSelected: selectedView == .help,
                        action: {
                            selectedView = selectedView == .help ? .search : .help
                        }
                    )
                }
                .padding(.horizontal, SeekTheme.spacingMedium)
                .padding(.vertical, SeekTheme.spacingMedium)
            }
        }
    }

}

struct NavigationButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: SeekTheme.spacingSmall) {
            Image(systemName: icon)
                .foregroundColor(isSelected ? SeekTheme.appPrimary : SeekTheme.appTextSecondary)
                .frame(width: 16)

            Text(title)
                .foregroundColor(isSelected ? SeekTheme.appPrimary : SeekTheme.appTextPrimary)
                .font(.system(size: 13))

            Spacer()
        }
        .padding(.horizontal, SeekTheme.spacingMedium)
        .padding(.vertical, SeekTheme.spacingSmall)
        .background(
            RoundedRectangle(cornerRadius: SeekTheme.cornerRadiusSmall)
                .fill(isSelected ? SeekTheme.appSelection : (isPressed ? SeekTheme.appPressed : (isHovered ? SeekTheme.appHover : Color.clear)))
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: SeekTheme.spacingSmall) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(SeekTheme.appTextSecondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(SeekTheme.appTextTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, SeekTheme.spacingMedium)

            if isExpanded {
                VStack(alignment: .leading, spacing: SeekTheme.spacingXSmall) {
                    content()
                }
                .padding(.horizontal, SeekTheme.spacingMedium)
            }
        }
    }
}

struct SidebarItem: View {
    let icon: String
    let title: String
    let subtitle: String?
    let badge: String?
    let action: (() -> Void)?
    @State private var isHovered = false

    init(icon: String, title: String, subtitle: String? = nil, badge: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.action = action
    }

    var body: some View {
        HStack(spacing: SeekTheme.spacingSmall) {
            Image(systemName: icon)
                .foregroundColor(SeekTheme.appTextSecondary)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(SeekTheme.appTextPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(SeekTheme.appTextTertiary)
                }
            }

            Spacer()

            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(SeekTheme.appTextSecondary)
                    .padding(.horizontal, SeekTheme.spacingXSmall)
                    .padding(.vertical, 2)
                    .background(SeekTheme.appBadgeGray)
                    .cornerRadius(SeekTheme.cornerRadiusSmall)
            }
        }
        .padding(.horizontal, SeekTheme.spacingSmall)
        .padding(.vertical, 3)
        .background(isHovered ? SeekTheme.appHover : Color.clear)
        .cornerRadius(SeekTheme.cornerRadiusSmall)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            action?()
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
