import SwiftUI
import SwiftData

/// The shared add-item form used by both entry paths.
struct AddItemView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let scannedBarcode: String?
    let shoppingItem: ShoppingItem?

    @State private var name = ""
    @State private var category = "Produce"
    @State private var storage: StorageLocation = .fridge
    @State private var quantity = 1
    @State private var expiryDate = Calendar.current.date(
        byAdding: .day,
        value: 7,
        to: .now
    ) ?? .now
    @State private var canSaveExpiry = true

    private let categories = [
        "Produce", "Dairy", "Meat", "Bakery",
        "Frozen", "Grains", "Other"
    ]

    private let categoryColumns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 4
    )

    private let storageColumns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 3
    )

    init(
        scannedBarcode: String? = nil,
        shoppingItem: ShoppingItem? = nil
    ) {
        self.scannedBarcode = scannedBarcode
        self.shoppingItem = shoppingItem

        if let shoppingItem {
            _name = State(initialValue: shoppingItem.name)
            _category = State(initialValue: shoppingItem.category)
            _storage = State(initialValue: shoppingItem.storage)
            _quantity = State(
                initialValue: min(max(shoppingItem.quantity, 1), 99)
            )
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Button("Cancel") {
                    dismiss()
                }
                .font(.headline)

                Text("Add to My Kitchen")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.cozyBrown)

                CozySection(title: "What is it?") {
                    TextField("Item name", text: $name)
                        .font(.title3)

                    if let scannedBarcode {
                        LabeledContent(
                            "Scanned barcode",
                            value: scannedBarcode
                        )
                    }
                }

                CozySection(title: "Category") {
                    LazyVGrid(columns: categoryColumns, spacing: 8) {
                        ForEach(categories, id: \.self) { option in
                            CozyChoiceButton(
                                title: option,
                                icon: categoryIcon(for: option),
                                isSelected: category == option
                            ) {
                                category = option
                            }
                        }
                    }
                }

                CozySection(title: "Stored in") {
                    LazyVGrid(columns: storageColumns, spacing: 8) {
                        ForEach(StorageLocation.allCases) { location in
                            CozyChoiceButton(
                                title: location.rawValue,
                                icon: storageIcon(for: location.rawValue),
                                isSelected: storage == location
                            ) {
                                storage = location
                            }
                        }
                    }
                }

                CozySection(title: "Details") {
                    Stepper(
                        "Quantity: \(quantity)",
                        value: $quantity,
                        in: 1...99
                    )

                    if let shoppingItem {
                        Text(partialPurchaseHint(for: shoppingItem))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                CozySection(title: "Use By") {
                    UseByDateSection(
                        expiryDate: $expiryDate,
                        canSave: $canSaveExpiry,
                        itemName: name,
                        storage: storage
                    )
                }
            }
            .padding(20)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.cozyCream)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                addItem()
            } label: {
                Text("Add to Kitchen")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        Color.cozyBrown.opacity(
                            trimmedName.isEmpty ? 0.4 : 1
                        ),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
            }
            .disabled(trimmedName.isEmpty || !canSaveExpiry)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.cozyCream)
        }
        .tint(.cozyBrown)
        .preferredColorScheme(.light)
    }

    // Handles partial purchases from the shopping list.
    private func partialPurchaseHint(for item: ShoppingItem) -> String {
        if quantity < item.quantity {
            return "You need \(item.quantity). \(item.quantity - quantity) will stay on your shopping list."
        }

        return "You need \(item.quantity). Buying fewer leaves the rest on your shopping list."
    }

    // Chooses the icon shown on each category button.
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Produce": "carrot"
        case "Dairy": "drop"
        case "Meat": "fork.knife"
        case "Bakery": "birthday.cake"
        case "Frozen": "snowflake"
        case "Grains": "leaf"
        default: "basket"
        }
    }

    // Chooses the icon shown on each storage button.
    private func storageIcon(for location: String) -> String {
        switch location {
        case "Fridge": "refrigerator"
        case "Freezer": "snowflake"
        default: "cabinet"
        }
    }

    // Inserts the pantry item and dismisses the sheet.
    private func addItem() {
        let newItem = PantryItem(
            name: trimmedName,
            category: category,
            storage: storage,
            quantity: quantity,
            barcode: scannedBarcode ?? shoppingItem?.barcode,
            expiryDate: expiryDate
        )

        modelContext.addToPantry(newItem, from: shoppingItem)
        dismiss()
    }
}

// A rounded card with a small heading above its content.
private struct CozySection<Content: View>: View {
    let title: String

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(Color.cozyBrown)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.cozyCard,
            in: RoundedRectangle(cornerRadius: 20)
        )
    }
}

// A tappable icon button that turns brown when selected.
private struct CozyChoiceButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(.caption.bold())
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                isSelected ? Color.cozyBrown : Color.cozyCream,
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
