import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            PantryListView()
                .tabItem {
                    Label("Pantry", systemImage: "refrigerator")
                }

            ComingSoonView(
                title: "Scan",
                message: "Barcode scanning is coming soon. Tap + on the Pantry tab to add items."
            )
            .tabItem {
                Label("Scan", systemImage: "barcode.viewfinder")
            }

            ComingSoonView(
                title: "Cook",
                message: "Recipe suggestions are coming soon."
            )
            .tabItem {
                Label("Cook", systemImage: "fork.knife")
            }
        }
    }
}

struct ComingSoonView: View {
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: "hammer",
                description: Text(message)
            )
            .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PantryItem.self, inMemory: true)
}
