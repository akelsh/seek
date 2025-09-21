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
                .onAppear {
                    configureWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
    }

    private func configureWindow() {
        if let window = NSApplication.shared.windows.first {
            window.isOpaque = false
            // Use adaptive background color
            window.backgroundColor = NSColor(name: nil) { appearance in
                switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
                case .darkAqua:
                    return NSColor(red: 22/255, green: 22/255, blue: 24/255, alpha: 1.0) // Dark mode
                default:
                    return NSColor(red: 250/255, green: 250/255, blue: 252/255, alpha: 1.0) // Light mode
                }
            }
        }
    }
}
