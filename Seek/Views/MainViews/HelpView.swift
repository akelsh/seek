import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack {
            Text("Help")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(SeekTheme.appTextPrimary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Help")
    }
}

#Preview {
    HelpView()
}
