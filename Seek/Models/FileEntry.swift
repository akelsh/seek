import Foundation

struct FileEntry: Identifiable, Codable {
    // Use fullPath as the unique identifier instead of database ID
    var id: String { fullPath }

    let name: String
    let fullPath: String
    let isDirectory: Bool
    let fileExtension: String?
    let size: Int64?
    let dateModified: TimeInterval

    init(name: String, fullPath: String, isDirectory: Bool, fileExtension: String? = nil, size: Int64? = nil, dateModified: Date) {
        self.name = name
        self.fullPath = fullPath
        self.isDirectory = isDirectory
        self.fileExtension = isDirectory ? nil : fileExtension
        self.size = isDirectory ? nil : size
        self.dateModified = dateModified.timeIntervalSince1970
    }


    // Helper to get Date object when needed for UI
    var dateModifiedAsDate: Date {
        return Date(timeIntervalSince1970: dateModified)
    }
}

extension FileEntry {
    var formattedSize: String? {
        guard let size = size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}