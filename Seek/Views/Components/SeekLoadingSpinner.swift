import SwiftUI

struct SeekLoadingSpinner: View {
    @State private var isRotating = false
    @State private var trimEnd: CGFloat = 0.6

    var body: some View {
        ZStack {
            // Background circle (faded)
            Circle()
                .stroke(
                    SeekTheme.appTextTertiary.opacity(0.2),
                    lineWidth: 3
                )

            // Animated arc
            Circle()
                .trim(from: 0, to: trimEnd)
                .stroke(
                    LinearGradient(
                        colors: [
                            SeekTheme.appPrimary,
                            SeekTheme.appPrimary.opacity(0.5)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false),
                    value: isRotating
                )
        }
        .frame(width: 48, height: 48)
        .onAppear {
            isRotating = true

            // Animate the arc length
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                trimEnd = 0.2
            }
        }
    }
}

#Preview {
    SeekLoadingSpinner()
        .frame(width: 48, height: 48)
        .padding()
}