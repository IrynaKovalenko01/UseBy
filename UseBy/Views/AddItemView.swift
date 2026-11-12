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

    /// Set when the form is opened from the shopping list.
    let shoppingItem: ShoppingItem?

    @State private var name = ""
    @State private var category = "Produce"
    @State private var storage: StorageLocation = .fridge
    @State private var quantity = 1
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var canSaveExpiry = true

    private let categories = ["Produce", "Dairy", "Meat", "Bakery", "Frozen", "Grains", "Other"]

    // Four equal columns for the category buttons.
    private let categoryColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    // Three equal columns for the storage buttons.
    private let storageColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    /// The default initializer supports manual entry; passing a code activates
    /// the scanner continuation variant without duplicating the form.
    init(scannedBarcode: String? = nil, shoppingItem: ShoppingItem? = nil) {
        self.scannedBarcode = scannedBarcode
        self.shoppingItem = shoppingItem
        // Prefill from the shopping list entry when there is one.
        if let shoppingItem {
            _name = State(initialValue: shoppingItem.name)
            _category = State(initialValue: shoppingItem.category)
            _storage = State(initialValue: shoppingItem.storage)
            _quantity = State(initialValue: min(max(shoppingItem.quantity, 1), 99))
        }
    }

    /// Trim before validation and persistence so whitespace-only names cannot
    /// create pantry records and saved names do not have accidental outer space.
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Closes the sheet without inserting a record.
                Button("Cancel") {
                    dismiss()
                }
                .font(.headline)

                // Large title that matches the My Kitchen header.
                Text("Add to My Kitchen")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.cozyBrown)

                // Item name, plus the barcode when the item was scanned.
                CozySection(title: "What is it?") {
                    TextField("Item name", text: $name)
                        .font(.title3)

                    // A barcode identifies the product but cannot supply expiry,
                    // storage, or quantity, so those remain user-entered fields.
                    if let scannedBarcode {
                        LabeledContent("Scanned barcode", value: scannedBarcode)
                    }
                }

                // Tappable category buttons.
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

                // Tappable storage buttons.
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

                // Quantity.
                CozySection(title: "Details") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)

                    // Explains partial purchases when coming from the shopping list.
                    if let shoppingItem {
                        Text(partialPurchaseHint(for: shoppingItem))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    // Users can either enter a date or request a FoodKeeper estimate.
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
        }
        // Lets people drag the list down to hide the keyboard.
        .scrollDismissesKeyboard(.interactively)
        // Puts the warm cream color behind the whole screen.
        .background(Color.cozyCream)
        // Keeps the Add button visible at the bottom of the screen.
        .safeAreaInset(edge: .bottom) {
            Button {
                addItem()
            } label: {
                Text("Add to Kitchen")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        // Looks faded until the item has a name.
                        Color.cozyBrown.opacity(trimmedName.isEmpty ? 0.4 : 1),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
            }
            .disabled(trimmedName.isEmpty || !canSaveExpiry)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.cozyCream)
        }
        // Makes accents warm brown.
        .tint(.cozyBrown)
        // Keeps light mode on so the text stays readable on cream.
        .preferredColorScheme(.light)
    }

    /// Deals with the situation when you buy fewer than the shopping list entry's quantity.
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
        // Makes each section fill the available width.
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cozyCard, in: RoundedRectangle(cornerRadius: 20))
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
        // Stops iOS from adding its default button styling.
        .buttonStyle(.plain)
        // Tells VoiceOver which option is selected.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
