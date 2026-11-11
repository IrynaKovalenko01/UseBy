import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: PantryItem
    @State private var showingEdit = false

    // The large text in the cube: "!" if expired, otherwise the days left.
    private var countdownNumber: String {
        item.daysLeft < 0 ? "!" : "\(item.daysLeft)"
    }

    // The small text under the number, matched to the days left.
    private var countdownLabel: String {
        switch item.daysLeft {
        case ..<0: "expired"
        case 0: "today"
        case 1: "day left"
        default: "days left"
        }
    }

    var body: some View {
        Form {
            // Header: large countdown cube next to the item name.
            Section {
                HStack(spacing: 16) {
                    // Countdown cube, tinted with the item's urgency color.
                    VStack(spacing: 0) {
                        Text(countdownNumber)
                            .font(.title.bold())
                        Text(countdownLabel)
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Color.cozyBrown)
                    .frame(width: 84, height: 80)
                    .background(
                        item.urgency.color.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    // Reads the cube as one phrase, like "7 days left".
                    .accessibilityElement(children: .combine)

                    // Item name and where it's stored.
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color.cozyBrown)
                        Text(item.storage.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                // Removes the white card behind the header, so it sits on the background.
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("Item") {
                LabeledContent("Name", value: item.name)
                LabeledContent("Category", value: item.category)
                LabeledContent("Stored in", value: item.storage.rawValue)
                LabeledContent("Quantity", value: "\(item.quantity)")
            }
            // White card background for each row.
            .listRowBackground(Color.cozyCard)

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
            .listRowBackground(Color.cozyCard)

            Section {
                Button("Edit") {
                    showingEdit = true
                }
                Button("Discard", role: .destructive) {
                    modelContext.delete(item)
                    dismiss()
                }
            }
            .listRowBackground(Color.cozyCard)
        }
        // Hides the default gray background.
        .scrollContentBackground(.hidden)
        // Puts the off-white color behind the whole screen.
        .background(Color.cozyCream)
        // Keeps the item name for the Back button, but the header shows it large.
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        // Makes the Back and Edit buttons dark plum.
        .tint(.cozyBrown)
        .sheet(isPresented: $showingEdit) {
            EditItemView(item: item)
        }
    }
}
