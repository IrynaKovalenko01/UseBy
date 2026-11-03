import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            PantryListView()
                .tabItem {
                    Label("Pantry", systemImage: "refrigerator")
                }

            // ScanProductView owns the camera-to-add-form workflow. Keeping it as
            // the tab root makes barcode entry available alongside manual Pantry
            // entry and preserves its scanner session while the tab is selected.
            ScanProductView()
            .tabItem {
                Label("Scan", systemImage: "barcode.viewfinder")
            }

            ComingSoonView(
                title: "Cookbook",
                heading: "Recipes are coming soon",
                message: "We'll suggest recipes that use your soonest-expiring food first.",
                icon: "book.closed"
            )
            .tabItem {
                Label("Cookbook", systemImage: "book.closed")
            }
        }
        // Makes the selected tab warm brown instead of blue.
        .tint(.cozyBrown)
        // Keeps light mode on so the text stays readable on cream.
        .preferredColorScheme(.light)
    }
}

// A cozy placeholder for features that aren't ready yet.
struct ComingSoonView: View {
    let title: String
    let heading: String
    let message: String
    let icon: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                // Large title that matches the My Kitchen header.
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.cozyBrown)

                // Pushes the card toward the middle of the screen.
                Spacer()

                // Card with the icon and coming soon message.
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 56))
                        .foregroundStyle(Color.cozyBrown)
                    Text(heading)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(28)
                .frame(maxWidth: .infinity)
                .background(Color.cozyCard, in: RoundedRectangle(cornerRadius: 20))

                // Keeps the card centered by balancing the space above it.
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            // Puts the warm cream color behind the whole screen.
            .background(Color.cozyCream)
            // Hides the default top bar because this screen has its own title.
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PantryItem.self, inMemory: true)
}
