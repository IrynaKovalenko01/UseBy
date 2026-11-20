import SwiftUI

struct LoadingScreenView: View {

    var body: some View {
        VStack(spacing: 20) {

            Image(systemName: "refrigerator.fill")
                .font(.system(size: 65))
                .foregroundStyle(Color.cozyBrown)

            Text("UseBy")
                .font(.system(
                    size: 40,
                    weight: .bold,
                    design: .serif
                ))
                .foregroundStyle(Color.cozyBrown)

            Text("Placeholder")
                .foregroundStyle(.secondary)

            ProgressView("Loading your pantry...")
                .tint(Color.cozyBrown)
                .padding(.top, 30)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cozyCream)
        .preferredColorScheme(.light)
    }
}

#Preview {
    LoadingScreenView()
}


