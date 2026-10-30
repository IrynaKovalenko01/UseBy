import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: PantryItem
    @State private var showingEdit = false
    
    var body: some View {
        Form {
            Section("Item") {
                LabeledContent("Name", value: item.name)
                LabeledContent("Category", value: item.category)
                LabeledContent("Stored in", value: item.storage.rawValue)
                LabeledContent("Quantity", value: "\(item.quantity)")
            }
            
            Section("Expiration") {
                LabeledContent(
                    "Use by",
                    value: item.expiryDate.formatted(date: .abbreviated, time: .omitted)
                )
                LabeledContent(
                    "Added",
                    value: item.addedDate.formatted(date: .abbreviated, time: .omitted)
                )
            }
            
            Section {
                Button("Edit") {
                    showingEdit = true
                }
                Button("Discard", role: .destructive) {
                    modelContext.delete(item)
                    dismiss()
                }
            }
        }
        .navigationTitle(item.name)
        .sheet(isPresented: $showingEdit) {
            EditItemView(item: item)
        }
    }
}
