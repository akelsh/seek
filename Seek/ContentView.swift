import SwiftUI

struct ContentView: View {
    @ObservedObject var appStateManager: AppStateManager

    var body: some View {
        ZStack {
            // Main content based on app state
            Group {
                switch appStateManager.currentState {
                case .onboarding:
                    OnboardingView(appStateManager: appStateManager)
                        .transition(.opacity)

                case .indexing:
                    IndexingView(appStateManager: appStateManager)
                        .transition(.opacity)

                case .mainApp:
                    MainAppView()
                        .transition(.opacity)

                case .indexingError(let errorMessage):
                    IndexingErrorView(errorMessage: errorMessage, appStateManager: appStateManager)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appStateManager.currentState)
        .onAppear {
            // Initialize basic app services
            initializeApp()
        }
    }

    private func initializeApp() {
        let _ = DatabaseService.shared
    }
}

#Preview {
    ContentView(appStateManager: AppStateManager())
}
