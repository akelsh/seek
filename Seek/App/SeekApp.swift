import SwiftUI

@main
struct SeekApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    // Clean up file system monitoring when app terminates
                    FileSystemMonitor.shared.stopMonitoring()
                }
        }
    }
}
