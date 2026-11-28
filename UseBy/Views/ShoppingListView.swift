import SwiftUI
import SwiftData

/// Vaibhav Paranji - 11/9/2026

struct ShoppingListView: View {
    /// Shared SwiftData context used when adding or removing list entries.
    @Environment(\.modelContext) private var modelContext
    /// Keeps the visible list synchronized with stored shopping items.
    @Query(sort: \ShoppingItem.addedDate) private var items: [ShoppingItem]

    /// Draft text for the quick-add row at the top of the list.
    @State private var newName = ""
    /// Tapping a row opens the Add form prefilled with this item.
    @State private var itemToStock: ShoppingItem?

    /// Removes whitespace before validating or saving a quick-add entry.
    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Screen heading and quick-add controls stay above the scrolling
            // list, including when there are no items yet.
            Text("Shopping List")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Color.cozyBrown)
                .padding(.horizontal, 20)

            // Quick-add row
            HStack(spacing: 10) {
                TextField("Add an item", text: $newName)
                    .submitLabel(.done)
                    .onSubmit(addItem)
                    .padding(14)
                    .background(Color.cozyCard, in: RoundedRectangle(cornerRadius: 16))

                Button(action: addItem) {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Color.cozyBrown.opacity(trimmedNewName.isEmpty ? 0.4 : 1),
                            in: Circle()
                        )
                }
                .disabled(trimmedNewName.isEmpty)
                .accessibilityLabel("Add to Shopping List")
            }
            .padding(.horizontal, 20)

            if items.isEmpty {
                // Explain the empty state and how list entries are used.
                Spacer()
                ContentUnavailableView(
                    "Nothing to buy",
                    systemImage: "cart",
                    description: Text("Add items above. They leave the list once you add them to your pantry.")
                )
                Spacer()
            } else {
                // Tapping a row opens the pantry-add form; swipe actions let
                // the user remove entries they no longer need.
                List {
                    ForEach(items) { item in
                        Button {
                            itemToStock = item
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.title3.bold())
                                        .foregroundStyle(.primary)
                                    Text("Qty \(item.quantity) · Tap when you've bought it")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.bold())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Color.cozyCard)
                    }
                    .onDelete(perform: deleteItems)
                }
                .listRowSpacing(10)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.top, 8)
        .background(Color.cozyCream)
        // Dismiss the keyboard while the user scrolls through the list.
        .scrollDismissesKeyboard(.interactively)
        // Retain the selected model as the sheet input while the add form is open.
        .sheet(item: $itemToStock) { item in
            AddItemView(shoppingItem: item)
        }
        .tint(.cozyBrown)
        .preferredColorScheme(.light)
    }

    private func addItem() {
        // The model helper merges an existing matching product, then clear the
        // draft so another item can be entered immediately.
        ShoppingItem.add(ShoppingItem(name: trimmedNewName), in: modelContext)
        newName = ""
    }

    /// Deletes the rows selected by SwiftUI's list swipe-to-delete gesture.
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(items[index]) }
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(for: [PantryItem.self, ShoppingItem.self], inMemory: true)
}