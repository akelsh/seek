import SwiftUI

struct ContentView: View {
    @ObservedObject var appStateManager: AppStateManager

    var body: some View {
        ZStack {
            // Main content based on app state
            Group {
                switch appStateManager.currentState {
                case .onboarding:
                    OnboardingView()
                        .transition(.opacity)

                case .mainApp:
                    MainAppView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appStateManager.currentState)
        .onAppear {
            // Initialize the app services
            initializeApp()
        }
    }

    private func initializeApp() {
        // Initialize database service
        let _ = DatabaseService.shared

        // Start monitoring if not in onboarding
        if appStateManager.currentState == .mainApp {
            Task {
                await FileSystemMonitor.shared.startMonitoringWithRecovery()
            }
        }
    }
}

#Preview {
    ContentView(appStateManager: AppStateManager())
}
