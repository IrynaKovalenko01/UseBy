import SwiftUI

// Tyler Todd
extension View {
    func appBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [.black, Color(white: 0.2)],  
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
    }
}