import SwiftUI

struct IndexingView: View {
    @ObservedObject var appStateManager: AppStateManager

    var body: some View {
        ZStack {
            // Background
            SeekTheme.appBackground
                .ignoresSafeArea()

            VStack(spacing: SeekTheme.spacingLarge) {
                Spacer()

                // Loading spinner
                SeekLoadingSpinner()

                VStack(spacing: SeekTheme.spacingMedium) {
                    // Use the dynamic message from appStateManager with fixed sizing to prevent layout conflicts
                    Text(appStateManager.indexingMessage)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(SeekTheme.appTextPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 30) // Prevent layout jumps from text changes
                        .id("indexing-message") // Stable identity to prevent animation conflicts

                    // Simple encouraging message
                    Text("This will just take a moment")
                        .font(.body)
                        .foregroundColor(SeekTheme.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 400) // Slightly wider to accommodate text
                .frame(minHeight: 100) // Fixed minimum height to prevent layout shifts

                Spacer()
            }
        }
        .clipped() // Prevent any layout overflow
    }
}

struct IndexingErrorView: View {
    let errorMessage: String
    @ObservedObject var appStateManager: AppStateManager

    var body: some View {
        VStack(spacing: SeekTheme.spacingLarge) {
            Spacer()

            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            VStack(spacing: SeekTheme.spacingMedium) {
                Text("Indexing Error")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(SeekTheme.appTextPrimary)

                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(SeekTheme.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: SeekTheme.spacingSmall) {
                    // Retry button
                    Button(action: {
                        appStateManager.retryIndexing()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.headline)
                        .foregroundColor(SeekTheme.appTextPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(SeekTheme.appPrimary.opacity(0.1))
                        .cornerRadius(SeekTheme.cornerRadiusSmall)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Skip button (go to main app without indexing)
                    Button(action: {
                        Task { @MainActor in
                            appStateManager.currentState = .mainApp
                        }
                    }) {
                        Text("Continue without indexing")
                            .font(.caption)
                            .foregroundColor(SeekTheme.appTextTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: 400)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SeekTheme.appBackground)
    }
}

// Preview
#Preview {
    VStack {
        IndexingView(appStateManager: {
            let manager = AppStateManager()
            manager.indexingMessage = "Processing files..."
            manager.indexingProgress = 0.7
            manager.filesProcessed = 1250
            manager.totalFiles = 1800
            return manager
        }())
    }
}

#Preview("Error State") {
    IndexingErrorView(
        errorMessage: "Failed to access the file system. Please check permissions.",
        appStateManager: AppStateManager()
    )
}