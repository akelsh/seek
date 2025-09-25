import SwiftUI
import AppKit

@main
struct SeekApp: App {
    @StateObject private var appStateManager = AppStateManager()

    var body: some Scene {
        WindowGroup {
            ContentView(appStateManager: appStateManager)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    // Clean up file system monitoring when app terminates
                    FileSystemMonitor.shared.stopMonitoring()
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
