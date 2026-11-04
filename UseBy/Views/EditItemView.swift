import SwiftUI
import SwiftData

/// An edit sheet that copies a saved item's values into temporary state. Saving
/// applies the draft; cancelling leaves the original record intact.
struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss

    /// SwiftData-managed item to update. The item is mutated only in save().
    let item: PantryItem

    @State private var name: String
    @State private var category: String
    @State private var storage: StorageLocation
    @State private var quantity: Int
    @State private var expiryDate: Date

    private let categories = ["Produce", "Dairy", "Meat", "Bakery", "Frozen", "Grains", "Other"]

    init(item: PantryItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _storage = State(initialValue: item.storage)
        _quantity = State(initialValue: item.quantity)
        _expiryDate = State(initialValue: item.expiryDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Item name", text: $name)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }

                Section("Storage") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                        }
                    }

                    Picker("Stored in", selection: $storage) {
                        ForEach(StorageLocation.allCases) { location in
                            Text(location.rawValue).tag(location)
                        }
                    }
                }

                Section("Expiration") {
                    DatePicker("Use by", selection: $expiryDate, displayedComponents: .date)
                }

                if let barcode = item.barcode {
                    Section("Scanned product") {
                        LabeledContent("Barcode", value: barcode)
                    }
                }
            }
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.category = category
        item.storageRaw = storage.rawValue
        item.quantity = quantity
        item.expiryDate = expiryDate
        dismiss()
    }
}
