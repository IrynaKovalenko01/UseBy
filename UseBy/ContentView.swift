import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            PantryListView()
                .tabItem {
                    Label("Pantry", systemImage: "refrigerator")
                }

            ScanProductView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }

            RecipeListView()
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
