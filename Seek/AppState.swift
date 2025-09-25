import Foundation

/// Represents the current state/view of the application
enum AppState {
    case onboarding
    case mainApp
}

/// Observable class to manage app state transitions
@MainActor
class AppStateManager: ObservableObject {
    @Published var currentState: AppState = .onboarding

    /// Check if user has completed onboarding
    private var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    init() {
        // Check if user should skip onboarding
        if hasCompletedOnboarding {
            currentState = .mainApp
        }
    }

    /// Mark onboarding as completed and move to main app
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        currentState = .mainApp
    }

    /// Reset to onboarding (for testing or reset functionality)
    func resetToOnboarding() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        currentState = .onboarding
    }
}