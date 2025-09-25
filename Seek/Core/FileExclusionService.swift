import Foundation

class FileExclusionService {
    
    // ------------------
    // MARK: - Properties
    // ------------------

    // Precomputed exclusion set for efficient O(1) lookup
    private let pathsToExclude: Set<String>
    
    // -----------------
    // MARK: - Singleton
    // -----------------

    static let shared = FileExclusionService()

    // ----------------------
    // MARK: - Initialization
    // ----------------------

    private init() {
        self.pathsToExclude = Set([
            "/dev",
            "/private",
            "/.fseventsd",
            "/System",
            "/System/Volumes",
            "/private/var/db",
            "/private",
            "/dev",
            "/Volumes",
            "/.fseventsd",
            "/Network",
            "/Library/Caches",
            "/Library/Logs",
            "/Library/Managed Preferences",
            "/Library/InstallerSandboxes",
            "/Library/Apple/System/Library/CoreServices",
            "/Library/DirectoryServices",
            "/Library/Keychains",
            "/Library/Security",
            "/Library/SystemMigration",
            "/Library/Updates",
            "/Library/Receipts",
            "/Library/Sandbox",
            "/Library/StagedExtensions",
            "/Library/Application Support/Apple/ParentalControls",
            "/Library/Application Support/Apple/AssetCache",
            "/tmp",
            "/var/folders",
            "/usr/sbin",
            "/usr/bin",
            "/sbin",
            "/bin"
        ])
    }
    
    // ----------------------
    // MARK: - Public Methods
    // ----------------------

    /// Main exclusion check for directories only
    func shouldExclude(path: String, name: String, isDirectory: Bool) -> Bool {
        // Only check directories
        if !isDirectory {
            return false
        }

        // Check if path is in exclusion list
        return pathsToExclude.contains(path)
    }

    /// Convenience method for URL-based checking
    func shouldExclude(url: URL, isDirectory: Bool) -> Bool {
        let path = url.path
        let name = url.lastPathComponent

        return shouldExclude(
            path: path,
            name: name,
            isDirectory: isDirectory
        )
    }

}
