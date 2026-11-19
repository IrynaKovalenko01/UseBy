import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: PantryItem
    @State private var showingEdit = false
    @State private var addedToList = false
    
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

                Button(addedToList ? "Added to Shopping List" : "Add to Shopping List") {
                    // Copies the pantry item's details into a shopping entry.
                    ShoppingItem.add(
                        ShoppingItem(
                            name: item.name,
                            category: item.category,
                            storage: item.storage,
                            quantity: 1,
                            barcode: item.barcode
                        ),
                        in: modelContext
                    )
                    addedToList = true
                }
                .disabled(addedToList)

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
