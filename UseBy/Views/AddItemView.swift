import SwiftUI
import SwiftData

/// The shared add-item form used by both entry paths.
///
/// Present this view in a sheet for manual entry. To recreate barcode entry,
/// initialize it with the code recognized by the scanner; the form then shows
/// the code read-only and saves it alongside the otherwise manually supplied
/// item details.
struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// A scanner-supplied code. It is nil for Pantry's normal "+" flow.
    let scannedBarcode: String?

    @State private var name = ""
    @State private var category = "Produce"
    @State private var storage: StorageLocation = .fridge
    @State private var quantity = 1
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    private let categories = ["Produce", "Dairy", "Meat", "Bakery", "Frozen", "Grains", "Other"]

    /// The default initializer supports manual entry; passing a code activates
    /// the scanner continuation variant without duplicating the form.
    init(scannedBarcode: String? = nil) {
        self.scannedBarcode = scannedBarcode
    }

    /// Trim before validation and persistence so whitespace-only names cannot
    /// create pantry records and saved names do not have accidental outer space.
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $name)

                // A barcode identifies the product but cannot supply expiry,
                // storage, or quantity, so those remain user-entered fields.
                if let scannedBarcode {
                    LabeledContent("Scanned barcode", value: scannedBarcode)
                }

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
                        // In either workflow, close the presented sheet without
                        // inserting a record.
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

    /// Inserts exactly one SwiftData record, including the optional code, then
    /// dismisses the enclosing sheet. SwiftData persists the inserted model in
    /// the container supplied by the app's root view.
    private func addItem() {
        let newItem = PantryItem(
            name: trimmedName,
            category: category,
            storage: storage,
            quantity: quantity,
            barcode: scannedBarcode,
            expiryDate: expiryDate
        )
        modelContext.insert(newItem)
        dismiss()
    }
}
