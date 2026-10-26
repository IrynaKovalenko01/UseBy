import SwiftUI
import SwiftData

extension Urgency {
    var color: Color {
        switch self {
        case .urgent: .red
        case .soon: .yellow
        case .safe: .green
        }
    }
}

struct PantryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.expiryDate) private var items: [PantryItem]
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Your pantry is empty",
                        systemImage: "refrigerator",
                        description: Text("Tap + to add your groceries.")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                PantryRow(item: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddItemView()
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

struct PantryRow: View {
    let item: PantryItem

    private var daysText: String {
        switch item.daysLeft {
        case ..<0: "Expired"
        case 0: "Today"
        case 1: "1 day"
        default: "\(item.daysLeft) days"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.urgency.color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                Text("\(item.storage.rawValue) · Qty \(item.quantity)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(daysText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PantryListView()
        .modelContainer(for: PantryItem.self, inMemory: true)
}
