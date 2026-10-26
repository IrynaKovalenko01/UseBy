import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = "Produce"
    @State private var storage: StorageLocation = .fridge
    @State private var quantity = 1
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    private let categories = ["Produce", "Dairy", "Meat", "Bakery", "Frozen", "Grains", "Other"]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $name)

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

                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)

                DatePicker("Use by", selection: $expiryDate, displayedComponents: .date)
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func addItem() {
        let newItem = PantryItem(
            name: trimmedName,
            category: category,
            storage: storage,
            quantity: quantity,
            expiryDate: expiryDate
        )
        modelContext.insert(newItem)
        dismiss()
    }
}
