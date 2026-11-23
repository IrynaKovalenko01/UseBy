import SwiftUI

struct LaunchContainerView: View {
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingScreenView()
                    // Identifies loading Screen
                    .accessibilityIdentifier("loadingScreen")
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .task {
            // Temporary delay for the loading screen.
            try? await Task.sleep(for: .seconds(2.5))

            withAnimation(.easeInOut(duration: 0.4)) {
                isLoading = false
            }
        }
    }
}

#Preview {
    LaunchContainerView()
}

