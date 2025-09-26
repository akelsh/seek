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
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeInOut(duration: 0.6)),
                            removal: .opacity.animation(.easeInOut(duration: 0.6).delay(0.1))
                        ))

                case .mainApp:
                    MainAppView()
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeInOut(duration: 0.6).delay(0.2)),
                            removal: .opacity.animation(.easeInOut(duration: 0.6))
                        ))

                case .indexingError(let errorMessage):
                    IndexingErrorView(errorMessage: errorMessage, appStateManager: appStateManager)
                        .transition(.opacity)
                }
            }
        }
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
