import SwiftUI

struct ContentView: View {
    @State private var statusMessage = "Database not initialized"
    @State private var dbPath = ""
    @State private var searchQuery = ""
    @State private var searchResults: [FileEntry] = []
    @State private var isSearching = false
    @State private var searchTime: TimeInterval = 0
    @State private var totalFiles = 0
    @State private var isIndexed = false
    @State private var lastIndexedDate: Date?
    @State private var isMonitoring = false
    @State private var monitoringStatus = "Initializing..."

    private let searchService = SearchService()

    var body: some View {
        VStack(spacing: 20) {
            Text("Seek Database Test")
                .font(.title)
                .padding()

            VStack(alignment: .leading, spacing: 10) {
                Text("Database: \(statusMessage)")
                    .foregroundColor(statusMessage.contains("initialized") ? .green : .orange)

                HStack {
                    Text("Indexed:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(isIndexed ? "✅ Yes" : "❌ No")
                        .font(.caption)
                        .foregroundColor(isIndexed ? .green : .red)

                    if let date = lastIndexedDate {
                        Text("(\(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("Monitoring:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if isMonitoring {
                        Text("✅ Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("🔄 \(monitoringStatus)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if !dbPath.isEmpty {
                    Text("DB Path: \(dbPath)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if totalFiles > 0 {
                    Text("Total indexed files: \(totalFiles)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            HStack {
                Button("Restart Monitoring") {
                    Task {
                        // Stop current monitoring
                        FileSystemMonitor.shared.stopMonitoring()

                        await MainActor.run {
                            isMonitoring = false
                            monitoringStatus = "Restarting..."
                        }

                        // Restart monitoring system
                        await startSmartMonitoring()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Force Reindex") {
                    Task {
                        do {
                            await MainActor.run {
                                statusMessage = "Force reindexing..."
                                isMonitoring = false
                                monitoringStatus = "Force reindexing..."
                            }

                            // Stop monitoring and clear status
                            FileSystemMonitor.shared.stopMonitoring()
                            try await DatabaseService.shared.clearIndexingStatus()

                            // Start fresh indexing and monitoring
                            await startSmartMonitoring()
                        } catch {
                            await MainActor.run {
                                statusMessage = "Reindexing failed: \(error)"
                                monitoringStatus = "Error: \(error.localizedDescription)"
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

            Divider()

            // Search Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Search Files")
                    .font(.headline)

                HStack {
                    TextField("Search (e.g., 'spot', '*.app', 'config AND json', '\"exact.js\"')", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            performSearch()
                        }

                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSearching)

                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                if searchTime > 0 {
                    Text("Found \(searchResults.count) results in \(String(format: "%.3f", searchTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Quick test buttons
                HStack(spacing: 5) {
                    Text("Quick tests:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("spot") { searchQuery = "spot"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("*.app") { searchQuery = "*.app"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("config AND json") { searchQuery = "config AND json"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("\"README\"") { searchQuery = "\"README\""; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("Debug DB") {
                        Task { await debugDatabase() }
                    }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Spacer()
                }

                // Boolean operators test buttons
                HStack(spacing: 5) {
                    Text("Boolean:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("config OR json") { searchQuery = "config OR json"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("pdf AND NOT temp") { searchQuery = "pdf AND NOT temp"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("NOT cache") { searchQuery = "NOT cache"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("*ify* OR *io*") { searchQuery = "*ify* OR *io*"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Spacer()
                }

                // Enhanced syntax test buttons
                HStack(spacing: 5) {
                    Text("Enhanced:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("config json") { searchQuery = "config json"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("config & json") { searchQuery = "config & json"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("config | json") { searchQuery = "config | json"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("!cache") { searchQuery = "!cache"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Button("(config | json) & !temp") { searchQuery = "(config | json) & !temp"; performSearch() }
                        .buttonStyle(.borderless)
                        .font(.caption)

                    Spacer()
                }

                // Search Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(searchResults) { entry in
                            HStack {
                                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundColor(entry.isDirectory ? .blue : .gray)
                                    .frame(width: 20)

                                VStack(alignment: .leading) {
                                    Text(entry.name)
                                        .font(.system(.body, design: .monospaced))
                                        .lineLimit(1)

                                    Text(entry.fullPath)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if let size = entry.formattedSize {
                                    Text(size)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 5)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                }
                .frame(maxHeight: 400)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .padding()

            Spacer()
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            initializeDatabase()
            Task {
                await updateFileCount()
                await updateIndexingStatus()
                await startSmartMonitoring()
            }
        }
    }

    private func initializeDatabase() {
        let _ = DatabaseService.shared
        statusMessage = "Database initialized successfully"

        // Get the database path for display
        let appSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        dbPath = "\(appSupportPath)/Seek/seek.db"
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }

        isSearching = true
        searchResults = []

        Task {
            do {
                let result = try await searchService.search(query: searchQuery, limit: 100)
                await MainActor.run {
                    searchResults = result.entries
                    searchTime = result.searchTime
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Search failed: \(error)"
                    isSearching = false
                }
            }
        }
    }

    private func updateFileCount() async {
        do {
            totalFiles = try await DatabaseService.shared.getFileCount()
        } catch {
            print("Failed to get file count: \(error)")
        }
    }

    private func debugDatabase() async {
        do {
            let dbService = DatabaseService.shared

            // Check what extensions exist
            let extensions = try await dbService.performRead { db in
                let sql = "SELECT DISTINCT file_extension FROM file_entries WHERE file_extension IS NOT NULL ORDER BY file_extension LIMIT 20"
                let statement = try db.prepare(sql)
                var exts: [String] = []
                for row in try statement.run() {
                    if let ext = row[0] as? String {
                        exts.append(ext)
                    }
                }
                return exts
            }

            print("🔍 DEBUG: Extensions in database: \(extensions)")

            // Check for .app files specifically
            let appFiles = try await dbService.performRead { db in
                let sql = "SELECT name, is_directory, file_extension FROM file_entries WHERE name LIKE '%.app' LIMIT 30"
                let statement = try db.prepare(sql)
                var files: [(String, Bool, String?)] = []
                for row in try statement.run() {
                    let name = row[0] as! String
                    let isDir = (row[1] as! Int64) != 0
                    let ext = row[2] as? String
                    files.append((name, isDir, ext))
                }
                return files
            }

            print("🔍 DEBUG: .app files in database (\(appFiles.count) found):")
            for (name, isDir, ext) in appFiles {
                print("   - \(name) | isDirectory: \(isDir) | extension: '\(ext ?? "nil")'")
            }

            // Check specifically for app extension
            let appExtensionCount = try await dbService.performRead { db in
                let sql = "SELECT COUNT(*) FROM file_entries WHERE file_extension = 'app'"
                let count = try db.scalar(sql) as! Int64
                return Int(count)
            }

            print("🔍 DEBUG: Files with extension='app': \(appExtensionCount)")

            // Check for Spotify specifically
            let spotifyFiles = try await dbService.performRead { db in
                let sql = "SELECT name, full_path, file_extension FROM file_entries WHERE name LIKE '%Spotify%'"
                let statement = try db.prepare(sql)
                var files: [(String, String, String?)] = []
                for row in try statement.run() {
                    let name = row[0] as! String
                    let path = row[1] as! String
                    let ext = row[2] as? String
                    files.append((name, path, ext))
                }
                return files
            }

            print("🔍 DEBUG: Spotify files in database (\(spotifyFiles.count) found):")
            for (name, path, ext) in spotifyFiles {
                print("   - \(name) | \(path) | extension: '\(ext ?? "nil")'")
            }

        } catch {
            print("🔍 DEBUG: Database query failed: \(error)")
        }
    }

    private func updateIndexingStatus() async {
        do {
            let status = try await DatabaseService.shared.getIndexingStatus()
            await MainActor.run {
                isIndexed = status.isIndexed
                lastIndexedDate = status.lastIndexedDate
            }
        } catch {
            print("Failed to get indexing status: \(error)")
        }
    }

    private func startSmartMonitoring() async {
        await MainActor.run {
            monitoringStatus = "Starting..."
        }

        let result = await FileSystemMonitor.shared.startMonitoringWithRecovery()

        await MainActor.run {
            if result.contains("Error") {
                monitoringStatus = result
                isMonitoring = false
            } else {
                monitoringStatus = result
                isMonitoring = true
            }
        }

        // Update status after monitoring starts
        await updateFileCount()
        await updateIndexingStatus()
    }
}

#Preview {
    ContentView()
}
