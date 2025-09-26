import SwiftUI

struct Sidebar: View {
    @Binding var selectedView: MainViewType
    @State private var quickAccessExpanded = true
    @State private var locationsExpanded = true
    @State private var filterByExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable filter sections
            ScrollView {
                VStack(alignment: .leading, spacing: SeekTheme.spacingLarge) {
                    quickAccessSection
                    locationsSection
                    filterBySection
                }
                .opacity(selectedView == .search ? 1.0 : 0.6)
                .animation(.easeInOut(duration: 0.3), value: selectedView)
                .padding(.vertical, SeekTheme.spacingMedium)
            }
            
            // Fixed navigation section at bottom
            Divider()
                .background(SeekTheme.appSeparator)
            
            navigationSection
        }
    }
    
    // ----------------------------
    // MARK: - Quick Access Section
    // ----------------------------
    
    private var quickAccessSection: some View {
        CollapsibleSection(
            title: "Quick Access",
            isExpanded: Binding(
                get: { selectedView == .search ? quickAccessExpanded : false },
                set: { if selectedView == .search { quickAccessExpanded = $0 } }
            ),
            isDisabled: selectedView != .search
        ) {
            VStack(spacing: SeekTheme.spacingXSmall) {
                SidebarItem(
                    icon: "clock.arrow.circlepath",
                    title: "Recent Searches",
                    badge: "5"
                ) {
                }
                
                SidebarItem(
                    icon: "star",
                    title: "Saved Searches"
                ) {
                    // TODO: Implement saved searches
                }
            }
        }
    }
    
    // -------------------------
    // MARK: - Locations Section
    // -------------------------
    
    private var locationsSection: some View {
        CollapsibleSection(
            title: "Locations",
            isExpanded: Binding(
                get: { selectedView == .search ? locationsExpanded : false },
                set: { if selectedView == .search { locationsExpanded = $0 } }
            ),
            isDisabled: selectedView != .search
        ) {
            VStack(spacing: SeekTheme.spacingXSmall) {
                SidebarItem(icon: "folder", title: "Documents") {
                    // TODO: Filter by documents folder
                }
                SidebarItem(icon: "arrow.down.circle", title: "Downloads") {
                    // TODO: Filter by downloads folder
                }
                SidebarItem(icon: "menubar.rectangle", title: "Desktop") {
                    // TODO: Filter by desktop
                }
                SidebarItem(icon: "square.grid.3x3", title: "Applications") {
                    // TODO: Filter by applications folder
                }
            }
        }
    }
    
    // -------------------------
    // MARK: - Filter By Section
    // -------------------------
    
    private var filterBySection: some View {
        CollapsibleSection(
            title: "Filter By",
            isExpanded: Binding(
                get: { selectedView == .search ? filterByExpanded : false },
                set: { if selectedView == .search { filterByExpanded = $0 } }
            ),
            isDisabled: selectedView != .search
        ) {
            VStack(alignment: .leading, spacing: SeekTheme.spacingMedium) {
                // Modified subsection
                VStack(alignment: .leading, spacing: SeekTheme.spacingXSmall) {
                    SectionHeader(title: "Modified")
                    
                    SidebarItem(icon: "clock", title: "Today") {
                        // TODO: Filter by today
                    }
                    SidebarItem(icon: "calendar.day.timeline.left", title: "This Week") {
                        // TODO: Filter by this week
                    }
                    SidebarItem(icon: "calendar", title: "This Month") {
                        // TODO: Filter by this month
                    }
                }
                
                // Type subsection
                VStack(alignment: .leading, spacing: SeekTheme.spacingXSmall) {
                    SectionHeader(title: "Type")
                    
                    SidebarItem(icon: "doc.text", title: "Documents") {
                        // TODO: Filter by documents
                    }
                    SidebarItem(icon: "photo", title: "Images") {
                        // TODO: Filter by images
                    }
                    SidebarItem(icon: "video", title: "Videos") {
                        // TODO: Filter by videos
                    }
                    SidebarItem(icon: "curlybraces", title: "Code") {
                        // TODO: Filter by code files
                    }
                    SidebarItem(icon: "archivebox.fill", title: "Archives") {
                        // TODO: Filter by archives
                    }
                }
                
                // Size subsection
                VStack(alignment: .leading, spacing: SeekTheme.spacingXSmall) {
                    SectionHeader(title: "Size")
                    
                    SidebarItem(icon: "doc.fill.badge.plus", title: "Large", subtitle: ">1GB") {
                        // TODO: Filter by large files
                    }
                    SidebarItem(icon: "doc.fill", title: "Medium", subtitle: "10MB-1GB") {
                        // TODO: Filter by medium files
                    }
                    SidebarItem(icon: "doc", title: "Small", subtitle: "<10MB") {
                        // TODO: Filter by small files
                    }
                }
            }
        }
    }
    
    // --------------------------
    // MARK: - Navigation Section
    // --------------------------
    
    private var navigationSection: some View {
        VStack(spacing: SeekTheme.spacingXSmall) {
            NavigationButton(
                icon: "magnifyingglass",
                title: "Search",
                isSelected: selectedView == .search
            ) {
                selectedView = .search
            }
            
            NavigationButton(
                icon: "gear",
                title: "Settings",
                isSelected: selectedView == .settings
            ) {
                selectedView = .settings
            }
            
            NavigationButton(
                icon: "questionmark.circle",
                title: "Help",
                isSelected: selectedView == .help
            ) {
                selectedView = .help
            }
        }
        .padding(SeekTheme.spacingMedium)
    }
}

// ----------------------
// MARK: - Section Header
// ----------------------

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundColor(SeekTheme.appTextSecondary)
            .padding(.leading, SeekTheme.spacingSmall)
    }
}

// -------------------------
// MARK: - Navigation Button
// -------------------------

struct NavigationButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SeekTheme.spacingSmall) {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? SeekTheme.appPrimary : SeekTheme.appTextSecondary)
                    .frame(width: 16)
                
                Text(title)
                    .foregroundColor(SeekTheme.appTextPrimary)
                    .font(.system(size: 13))
                
                Spacer()
            }
            .padding(.horizontal, SeekTheme.spacingMedium)
            .padding(.vertical, SeekTheme.spacingSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarButtonStyle(isSelected: isSelected))
    }
}

// ---------------------------
// MARK: - Custom Button Style
// ---------------------------

struct SidebarButtonStyle: ButtonStyle {
    let isSelected: Bool
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: SeekTheme.cornerRadiusSmall)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isSelected { return SeekTheme.appSelection }
        if isPressed { return SeekTheme.appPressed }
        if isHovered { return SeekTheme.appHover }
        return Color.clear
    }
}

// ---------------------------
// MARK: - Collapsible Section
// ---------------------------

struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let isDisabled: Bool
    let content: () -> Content
    
    init(title: String, isExpanded: Binding<Bool>, isDisabled: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self._isExpanded = isExpanded
        self.isDisabled = isDisabled
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: SeekTheme.spacingSmall) {
            Button(action: {
                if !isDisabled {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isDisabled ? SeekTheme.appTextTertiary : SeekTheme.appTextSecondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(isDisabled ? SeekTheme.appTextTertiary.opacity(0.5) : SeekTheme.appTextTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDisabled)
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

// --------------------
// MARK: - Sidebar Item
// --------------------

struct SidebarItem: View {
    let icon: String
    let title: String
    let subtitle: String?
    let badge: String?
    let action: () -> Void
    @State private var isHovered = false
    
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SeekTheme.spacingSmall) {
                Image(systemName: icon)
                    .foregroundColor(SeekTheme.appTextSecondary)
                    .frame(width: 16, height: 16)
                
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
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(isHovered ? SeekTheme.appHover : Color.clear)
        .cornerRadius(SeekTheme.cornerRadiusSmall)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
