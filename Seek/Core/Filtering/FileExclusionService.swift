import Foundation

class FileExclusionService {
    // Precomputed exclusion sets for efficient O(1) lookup
    private let developmentDirs: Set<String>
    private let developmentExtensions: Set<String>
    private let systemPaths: Set<String>
    private let systemDirs: Set<String>

    // Singleton instance
    static let shared = FileExclusionService()

    private init() {
        // Development directories and files
        self.developmentDirs = Set([
            // Package managers
            "node_modules",
            "pods",
            ".cocoapods",
            "vendor",
            "bower_components",
            ".dart_tool",
            "venv",
            ".venv",
            "env",
            ".env",

            // Version control
            ".git",
            ".svn",
            ".hg",
            ".bzr",
            ".fossil",

            // Build artifacts
            "build",
            "dist",
            "target",
            ".build",
            "deriveddata",
            "out",
            "bin",
            "obj",

            // IDE/Editor directories
            ".idea",
            ".vscode",
            ".vs",

            // Caches
            ".cache",
            ".npm",
            ".cargo",
            ".gradle",
            ".m2",
            "__pycache__",
            ".pytest_cache",
            ".mypy_cache",
            ".tox",
            ".ruff_cache",
            ".hypothesis",
            ".bundle",
            ".sass-cache"
        ].map { $0.lowercased() })

        self.developmentExtensions = Set([
            // Build artifacts
            "pyc", "pyo", "pyd",
            "o", "obj", "class",

            // Editor temp files
            "swp", "swo", "swn", "tmp", "temp",

            // Archives that are usually build artifacts
            "jar", "war", "ear"
        ].map { $0.lowercased() })

        // System paths (critical system directories - ALWAYS excluded)
        self.systemPaths = Set([
            // Critical paths that cause FileIDTree errors or system issues
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

        // System directory names
        self.systemDirs = Set([
            "system volume information",
            "$recycle.bin",
            ".spotlight-v100",
            ".documentrevisions-v100",
            ".fseventsd",
            ".temporaryitems",
            ".trashes",
            ".volumeicon.icns",
            ".com.apple.timemachine.donotpresent",
            ".timemachine",
            ".mobilesync",
            ".meteorcaches"
        ].map { $0.lowercased() })
    }

    /// Main exclusion check - efficient single method call
    func shouldExclude(path: String, name: String, isDirectory: Bool, hasExtension: Bool = false, `extension`: String? = nil) -> Bool {
        let nameLowercased = name.lowercased()

        // ALWAYS exclude critical system paths - no configuration can override this
        if systemPaths.contains(path) {
            return true
        }

        // Check user-configurable exclusions
        if SeekConfig.Indexing.FileExclusion.excludeDevelopmentDirs {
            // Check development directories
            if isDirectory && developmentDirs.contains(nameLowercased) {
                return true
            }

            // Check development file extensions
            if !isDirectory, let ext = `extension`?.lowercased(), developmentExtensions.contains(ext) {
                return true
            }
        }

        // Check system directory names (always excluded)
        if isDirectory && systemDirs.contains(nameLowercased) {
            return true
        }

        return false
    }

    /// Convenience method for URL-based checking
    func shouldExclude(url: URL, isDirectory: Bool) -> Bool {
        let path = url.path
        let name = url.lastPathComponent
        let fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension

        return shouldExclude(
            path: path,
            name: name,
            isDirectory: isDirectory,
            hasExtension: !url.pathExtension.isEmpty,
            extension: fileExtension
        )
    }

}