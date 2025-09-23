import SwiftUI

struct SeekLoadingSpinner: View {
    @State private var isRotating = false
    @State private var trimEnd: CGFloat = 0.6

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background circle (faded)
                Circle()
                    .stroke(
                        SeekTheme.appTextTertiary.opacity(0.2),
                        lineWidth: 4
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
                            lineWidth: 4,
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
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
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