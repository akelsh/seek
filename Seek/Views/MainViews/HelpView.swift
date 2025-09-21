import SwiftUI

struct HelpView: View {
    @State private var isContentVisible = false

    var body: some View {
        VStack {
            Text("Help")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(SeekTheme.appTextPrimary)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.5).delay(0.1), value: isContentVisible)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Help")
        .opacity(isContentVisible ? 1.0 : 0.0)
        .offset(y: isContentVisible ? 0 : 20)
        .animation(.easeInOut(duration: 0.4), value: isContentVisible)
        .onAppear {
            isContentVisible = true
        }
        .onDisappear {
            isContentVisible = false
        }
    }
}

#Preview {
    HelpView()
}
