import SwiftUI
import AppKit

struct SearchResultItem: View {
    let fileEntry: FileEntry
    @ObservedObject var searchViewModel: SearchViewModel
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(nsImage: searchViewModel.icon(for: fileEntry.fullPath))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileEntry.name)
                        .foregroundColor(SeekTheme.appTextPrimary)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    Text(fileEntry.fullPath)
                        .foregroundColor(SeekTheme.appTextSecondary)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let formattedSize = fileEntry.formattedSize {
                        Text(formattedSize)
                            .foregroundColor(SeekTheme.appTextTertiary)
                            .font(.system(size: 11))
                    }

                    Text(relativeDateString)
                        .foregroundColor(SeekTheme.appTextTertiary)
                        .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(backgroundColor)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Open") { action() }
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(fileEntry.fullPath, inFileViewerRootedAtPath: "")
            }
            Divider()
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fileEntry.fullPath, forType: .string)
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return SeekTheme.appSelection
        } else if isHovered {
            return SeekTheme.appHover
        }
        return Color.clear
    }

    private var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: fileEntry.dateModifiedAsDate, relativeTo: Date())
    }
}

#Preview {
    SearchResultItem(
        fileEntry: FileEntry(
            name: "Sample.txt",
            fullPath: "/Users/test/Sample.txt",
            isDirectory: false,
            fileExtension: "txt",
            size: 1024,
            dateModified: Date()
        ),
        searchViewModel: SearchViewModel(),
        isSelected: false,
        action: {}
    )
    .padding()
}