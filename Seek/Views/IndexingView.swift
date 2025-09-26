import SwiftUI

struct IndexingView: View {
    @ObservedObject var appStateManager: AppStateManager

    var body: some View {
        VStack(spacing: SeekTheme.spacingLarge) {
            Spacer()

            // Loading spinner
            SeekLoadingSpinner()
                .scaleEffect(1.5)

            VStack(spacing: SeekTheme.spacingMedium) {
                // Main message
                Text(appStateManager.indexingMessage)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(SeekTheme.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: appStateManager.indexingMessage)

                // Progress information
                if appStateManager.totalFiles > 0 {
                    VStack(spacing: SeekTheme.spacingXSmall) {
                        // Progress bar
                        ProgressView(value: appStateManager.indexingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(SeekTheme.appPrimary)
                            .animation(.easeInOut(duration: 0.2), value: appStateManager.indexingProgress)

                        // File count
                        HStack {
                            Text("\(appStateManager.filesProcessed) of \(appStateManager.totalFiles) files")
                                .font(.caption)
                                .foregroundColor(SeekTheme.appTextSecondary)

                            Spacer()

                            Text("\(Int(appStateManager.indexingProgress * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(SeekTheme.appTextSecondary)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: appStateManager.totalFiles)
                }

                // Encouraging message
                Text("This may take a moment depending on the number of files")
                    .font(.caption)
                    .foregroundColor(SeekTheme.appTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 300)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SeekTheme.appBackground)
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