import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let scannedBarcode: String?
    @State private var name = ""
    @State private var category = "Produce"
    @State private var storage: StorageLocation = .fridge
    @State private var quantity = 1
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var isLoadingProduct = false
    @State private var lookupMessage: String?
    private let categories = ["Produce", "Dairy", "Meat", "Bakery", "Frozen", "Grains", "Other"]

    init(scannedBarcode: String? = nil) { self.scannedBarcode = scannedBarcode }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    if isLoadingProduct {
                        HStack {
                            ProgressView().padding(.trailing, 4)
                            Text("Looking up product...").foregroundStyle(.secondary)
                        }
                    } else {
                        TextField("Item name", text: $name)
                    }
                    if let message = lookupMessage {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }
                Section("Storage") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
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
                if let scannedBarcode {
                    Section("Scanned product") {
                        LabeledContent("Barcode", value: scannedBarcode)
                    }
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .disabled(trimmedName.isEmpty || isLoadingProduct)
                }
            }
            .task(id: scannedBarcode) {
                guard let barcode = scannedBarcode, !barcode.isEmpty else { return }
                isLoadingProduct = true
                lookupMessage = nil
                do {
                    if let product = try await OpenFoodFactsAPI().product(barcode: barcode) {
                        if let productName = product.productName, !productName.isEmpty {
                            name = productName
                        }
                        if let tags = product.categoriesTags { category = mapOFFCategory(tags) }
                        lookupMessage = "Name filled in from Open Food Facts — edit if needed."
                    } else {
                        lookupMessage = "Product not found — enter the name manually."
                    }
                } catch {
                    lookupMessage = "Couldn't look up product — enter the name manually."
                }
                isLoadingProduct = false
            }
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private func addItem() {
        let newItem = PantryItem(name: trimmedName, category: category, storage: storage,
                                 quantity: quantity, barcode: scannedBarcode, expiryDate: expiryDate)
        modelContext.insert(newItem)
        dismiss()
    }

    private func mapOFFCategory(_ tags: [String]) -> String {
        let rules: [(String, String)] = [
            ("dairy", "Dairy"), ("milk", "Dairy"), ("cheese", "Dairy"), ("yogurt", "Dairy"),
            ("meat", "Meat"), ("fish", "Meat"), ("seafood", "Meat"), ("poultry", "Meat"),
            ("fruit", "Produce"), ("vegetable", "Produce"), ("produce", "Produce"),
            ("bread", "Bakery"), ("baked", "Bakery"), ("pastry", "Bakery"),
            ("frozen", "Frozen"),
            ("cereal", "Grains"), ("pasta", "Grains"), ("rice", "Grains"), ("grain", "Grains"),
        ]
        for tag in tags {
            let lower = tag.lowercased()
            for (keyword, mapped) in rules {
                if lower.contains(keyword) { return mapped }
            }
        }
        return "Other"
    }
}
