import Foundation

/// Represents the current state/view of the application
enum AppState: Equatable {
    case onboarding
    case indexing
    case mainApp
    case indexingError(String)
}

/// Observable class to manage app state transitions
@MainActor
class AppStateManager: ObservableObject {
    @Published var currentState: AppState = .onboarding

    // Indexing state tracking
    @Published var indexingProgress: Double = 0.0
    @Published var indexingMessage: String = AppStateManager.defaultIndexingMessage
    @Published var filesProcessed: Int = 0
    @Published var totalFiles: Int = 0

    private let indexingService = IndexingService()

    // MARK: - Constants
    private static let defaultIndexingMessage = "Getting things ready for you..."

    // User-friendly indexing messages for different stages
    private static let indexingMessages = [
        "Getting things ready for you...",
        "Preparing your files...",
        "Almost there...",
        "Finishing up..."
    ]

    /// Check if user has completed onboarding
    private var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    init() {
        // Check if user should skip onboarding
        if hasCompletedOnboarding {
            // Check if we need indexing before going to main app
            Task {
                await checkIndexingStatus()
            }
        }
    }

    /// Mark onboarding as completed and check if indexing is needed
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        Task {
            await checkIndexingStatus()
        }
    }

    /// Check if indexing is needed and start if necessary
    private func checkIndexingStatus() async {
        do {
            // Check if database is properly indexed
            let isIndexed = try await DatabaseService.shared.isIndexed()
            if !isIndexed {
                await startIndexing()
            } else {
                // Database already indexed, go to main app
                await MainActor.run {
                    currentState = .mainApp
                }
            }

            // Always start file system monitoring for real-time updates
            // (regardless of whether we needed indexing or not)
            await FileSystemMonitor.shared.startMonitoringWithRecovery()

        } catch {
            await MainActor.run {
                currentState = .indexingError("Failed to check indexing status: \(error.localizedDescription)")
            }
        }
    }

    /// Start the indexing process
    func startIndexing() async {
        await MainActor.run {
            currentState = .indexing
            indexingProgress = 0.0
            indexingMessage = AppStateManager.defaultIndexingMessage
            filesProcessed = 0
            totalFiles = 0
        }

        do {
            // Set up progress callback
            indexingService.setProgressCallback { [weak self] progress, filesProcessed, totalFiles, message in
                await self?.updateIndexingProgress(progress, filesProcessed: filesProcessed, totalFiles: totalFiles, message: message)
            }

            // Start indexing with progress updates
            try await indexingService.performSmartIndexing()

            // Indexing complete, go to main app
            await MainActor.run {
                currentState = .mainApp
            }
        } catch {
            await MainActor.run {
                currentState = .indexingError("Indexing failed: \(error.localizedDescription)")
            }
        }
    }

    /// Update indexing progress
    func updateIndexingProgress(_ progress: Double, filesProcessed: Int, totalFiles: Int, message: String? = nil) async {
        await MainActor.run {
            self.indexingProgress = progress
            self.filesProcessed = filesProcessed
            self.totalFiles = totalFiles

            // Use provided message or generate a progress-based friendly message
            if let message = message {
                self.indexingMessage = message
            } else {
                self.indexingMessage = AppStateManager.getProgressMessage(for: progress)
            }
        }
    }

    /// Update indexing message
    func updateIndexingMessage(_ message: String) async {
        await MainActor.run {
            self.indexingMessage = message
        }
    }

    /// Retry indexing after an error
    func retryIndexing() {
        Task {
            await startIndexing()
        }
    }

    /// Reset to onboarding (for testing or reset functionality)
    func resetToOnboarding() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        currentState = .onboarding
    }

    /// Get a user-friendly message based on indexing progress
    private static func getProgressMessage(for progress: Double) -> String {
        switch progress {
        case 0.0..<0.3:
            return indexingMessages[0] // "Getting things ready for you..."
        case 0.3..<0.7:
            return indexingMessages[1] // "Preparing your files..."
        case 0.7..<0.95:
            return indexingMessages[2] // "Almost there..."
        default:
            return indexingMessages[3] // "Finishing up..."
        }
    }
}