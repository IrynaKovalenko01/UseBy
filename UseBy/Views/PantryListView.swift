import SwiftUI
import SwiftData

// The app's cozy color palette.
extension Color {
    // Warm cream for the screen background.
    static let cozyCream = Color(red: 0.98, green: 0.95, blue: 0.89)
    // Lighter cream for the item cards.
    static let cozyCard = Color(red: 1.0, green: 0.99, blue: 0.96)
    // Warm brown for buttons and other accents.
    static let cozyBrown = Color(red: 0.55, green: 0.33, blue: 0.20)
}

extension Urgency {
    var color: Color {
        switch self {
        case .expired: .purple
        case .urgent: .red
        case .soon: .yellow
        case .safe: .green
        }
    }
}

struct PantryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.expiryDate) private var items: [PantryItem]
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Your pantry is empty",
                        systemImage: "refrigerator",
                        description: Text("Tap + to add your groceries.")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                PantryRow(item: item)
                            }
                            // Gives each row the lighter card color.
                            .listRowBackground(Color.cozyCard)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    // Separates the rows so they look like individual cards.
                    .listRowSpacing(10)
                    // Hides the default gray list background.
                    .scrollContentBackground(.hidden)
                }
            }
            // Puts the warm cream color behind the whole screen.
            .background(Color.cozyCream)
            // Name used by the Back button on the next screen.
            .navigationTitle("My Kitchen")
            // Hides the default top bar so we can use our own header.
            .toolbar(.hidden, for: .navigationBar)
            // Keeps our custom header at the top, above the list.
            .safeAreaInset(edge: .top) {
                HStack {
                    // Large title on the left.
                    Text("My Kitchen")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.cozyBrown)

                    // Pushes the + button to the right.
                    Spacer()

                    // Round button that opens the Add Item screen.
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(Color.cozyBrown)
                            .frame(width: 48, height: 48)
                            .background(Color.cozyCard, in: Circle())
                    }
                    // Gives VoiceOver a clear name for the icon-only button.
                    .accessibilityLabel("Add Item")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                // Keeps list items from showing through when they scroll under the header.
                .background(Color.cozyCream)
            }
            .sheet(isPresented: $showingAdd) {
                AddItemView()
            }
        }
        // Makes accents warm brown.
        .tint(.cozyBrown)
        // Keeps light mode on so the text stays readable on cream.
        .preferredColorScheme(.light)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

// One row in the pantry list: item details on the left, countdown badge on the right.
struct PantryRow: View {
    // The grocery item this row displays.
    let item: PantryItem

    // The large text in the badge: "!" if expired, otherwise the days left.
    private var countdownNumber: String {
        switch item.daysLeft {
        case ..<0: "!"
        default: "\(item.daysLeft)"
        }
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
        // Places the item details and badge side by side.
        HStack(spacing: 14) {
            // Item details, stacked and aligned to the left.
            VStack(alignment: .leading, spacing: 4) {
                // Item name, large and bold so it's easy to scan.
                Text(item.name)
                    .font(.title3.bold())
                // Where the item is stored and how many there are.
                Text("\(item.storage.rawValue) · Qty \(item.quantity)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Pushes the badge to the right edge of the row.
            Spacer()

            // Countdown badge: the number sits above its label.
            VStack(spacing: 0) {
                Text(countdownNumber)
                    .font(.title.bold())
                Text(countdownLabel)
                    .font(.caption.bold())
            }
            // Fixed size so the badges line up from row to row.
            .frame(width: 76, height: 64)
            // Rounded background tinted with the item's urgency color.
            // The low opacity keeps the text easy to read.
            .background(
                item.urgency.color.opacity(0.25),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        // Adds space above and below so the rows feel less cramped.
        .padding(.vertical, 6)
    }
}

#Preview {
    PantryListView()
        .modelContainer(for: PantryItem.self, inMemory: true)
}
