import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appStateManager: AppStateManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Seek")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(SeekTheme.appTextPrimary)

            Text("Your file search companion")
                .font(.subheadline)
                .foregroundColor(SeekTheme.appTextSecondary)

            Spacer()

            Button(action: {
                appStateManager.completeOnboarding()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(SeekTheme.appTextPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .cornerRadius(SeekTheme.cornerRadiusSmall)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SeekTheme.appBackground)
            }
}

#Preview {
    OnboardingView(appStateManager: AppStateManager())
}
