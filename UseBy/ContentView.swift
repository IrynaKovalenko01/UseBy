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
