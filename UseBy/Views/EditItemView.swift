import SwiftUI
import SwiftData

/// An edit sheet that copies a saved item's values into temporary state. Saving
/// applies the draft atomically; cancelling leaves the original record intact.
struct EditItemView: View {
    /// Closes this modal edit sheet after a cancel or successful save.
    @Environment(\.dismiss) private var dismiss

    /// SwiftData-managed item to update. The view intentionally mutates this
    /// object only in save(), keeping Cancel non-destructive.
    let item: PantryItem

    // The editable draft mirrors every user-modifiable persistent field.
    @State private var name: String
    @State private var category: String
    @State private var storage: StorageLocation
    @State private var amountKind: ItemAmountKind
    @State private var quantity: Int
    @State private var weightGrams: Double
    @State private var expiryDate: Date

    private let categories = ["Produce", "Dairy", "Meat", "Bakery", "Frozen", "Grains", "Other"]

    /// Seeds the edit draft from the saved record. This initializer deliberately
    /// performs only inexpensive value copies because SwiftUI may recreate views.
    init(item: PantryItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _storage = State(initialValue: item.storage)
        _amountKind = State(initialValue: item.amountKind)
        _quantity = State(initialValue: item.quantity)
        _weightGrams = State(initialValue: item.weightGrams ?? 100)
        _expiryDate = State(initialValue: item.expiryDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Item name", text: $name)

                    // Switching this control changes the amount input but retains
                    // both draft values, letting a person change their mind safely.
                    Picker("Add by", selection: $amountKind) {
                        ForEach(ItemAmountKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if amountKind == .quantity {
                        Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                    } else {
                        TextField("Weight in grams", value: $weightGrams, format: .number)
                            .keyboardType(.decimalPad)
                    }
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

                // A scanned barcode is product identity, not normal editable
                // inventory data, so it remains read-only during edits.
                if let barcode = item.barcode {
                    Section("Scanned product") {
                        LabeledContent("Barcode", value: barcode)
                    }
                }
            }
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (amountKind == .weight && weightGrams <= 0))
                }
            }
        }
    }

    /// Commits the draft to the SwiftData model. A nil weight represents
    /// quantity mode, while a non-nil weight represents grams mode.
    private func save() {
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.category = category
        item.storageRaw = storage.rawValue
        item.quantity = quantity
        item.weightGrams = amountKind == .weight ? weightGrams : nil
        item.expiryDate = expiryDate
        dismiss()
    }
}
