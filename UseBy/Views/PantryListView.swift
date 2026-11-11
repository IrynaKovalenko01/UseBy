import SwiftUI
import SwiftData

// Lets us write colors as hex codes, like Color(hex: 0xE01305).
extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// The app's colors, based on Jeweled Autumn Shades.
// The names are kept from the old palette so other screens still work.
extension Color {
    // Screen background: warm off-white, so the palette colors stand out.
    static let cozyCream = Color(hex: 0xF6F4F1)
    // Cards and buttons on the background: white.
    static let cozyCard = Color.white
    // Titles, buttons, and selected options: dark plum, easy to read.
    static let cozyBrown = Color(hex: 0x2B2433)

    // Palette colors, used for the countdown cubes and small accents.
    static let paletteRed = Color(hex: 0xE01305)
    static let paletteGold = Color(hex: 0xEDB55E)
    static let palettePurple = Color(hex: 0x7D58D9)
    static let paletteLavender = Color(hex: 0xD6C3DF)
    static let paletteGray = Color(hex: 0xE1E1E1)
    static let paletteGreen = Color(hex: 0x5CB855)
}

extension Urgency {
    // Bright palette color for shapes and backgrounds.
    var color: Color {
        switch self {
        case .expired: .palettePurple
        case .urgent: .paletteRed
        case .soon: .paletteGold
        case .safe: .paletteGreen
        }
    }

    // Darker version of the same color, for text that must be readable.
    var textColor: Color {
        switch self {
        case .expired: Color(hex: 0x6A5470)
        case .urgent: Color(hex: 0xC4100A)
        case .soon: Color(hex: 0x9A6510)
        case .safe: Color(hex: 0x357A30)
        }
    }
}

struct PantryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.expiryDate) private var items: [PantryItem]
    @State private var showingAdd = false

    // The selected filter chip. nil means "All".
    @State private var selectedStorage: StorageLocation? = nil

    // Items that match the selected filter chip.
    private var filteredItems: [PantryItem] {
        guard let selectedStorage else { return items }
        return items.filter { $0.storage == selectedStorage }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Your pantry is empty",
                        systemImage: "refrigerator",
                        description: Text("Tap + to add your groceries.")
                    )
                } else if filteredItems.isEmpty {
                    // Shown when a chip is selected but nothing is stored there.
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "tray",
                        description: Text("No items are stored in this spot.")
                    )
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                PantryRow(item: item)
                            }
                            // Space inside each box, around the cube and text.
                            .listRowInsets(EdgeInsets(top: 12, leading: 32, bottom: 12, trailing: 32))
                            // Draws each item as its own rounded white box.
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.cozyCard)
                                    // Space between the boxes and from the screen edges.
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 20)
                            )
                            // Hides the line between items, since the gap separates them.
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    // Plain list, so there's no extra space above the first item.
                    .listStyle(.plain)
                    // Hides the default list background.
                    .scrollContentBackground(.hidden)
                }
            }
            // Puts the off-white color behind the whole screen.
            .background(Color.cozyCream)
            // Name used by the Back button on the next screen.
            .navigationTitle("My Kitchen")
            // Hides the default top bar so we can use our own header.
            .toolbar(.hidden, for: .navigationBar)
            // Custom header at the top, above the list.
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // Large title in Apple's standard font.
                        Text("My Kitchen")
                            .font(.system(size: 40, weight: .semibold, design: .default))
                            .foregroundStyle(Color.cozyBrown)

                        // Pushes the + button to the right.
                        Spacer()

                        // Rounded button that opens the Add Item screen.
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                            .font(.title.weight(.semibold))
                            // Dark plum plus with no box behind it.
                            .foregroundStyle(Color.cozyBrown)
                            // Keeps the tap area large, even though only the plus shows.
                            .frame(width: 48, height: 48)
                        }
                        // Gives VoiceOver a clear name for the icon-only button.
                        .accessibilityLabel("Add Item")
                    }

                    // Filter chips: All, then one per storage location.
                    // Scrolls sideways if the chips don't fit.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: selectedStorage == nil) {
                                selectedStorage = nil
                            }
                            ForEach(StorageLocation.allCases) { location in
                                FilterChip(
                                    title: location.rawValue,
                                    isSelected: selectedStorage == location
                                ) {
                                    selectedStorage = location
                                }
                            }
                        }
                        // Keeps the chip outlines from being cut off.
                        .padding(.vertical, 2)
                    }
                    .padding(.top, 12)
                }
                // Makes the header fill the width, so the title stays on the left.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                // Small space between the filters and the first item.
                .padding(.bottom, 8)
                // Keeps list items from showing through when they scroll under the header.
                .background(Color.cozyCream)
            }
            .sheet(isPresented: $showingAdd) {
                AddItemView()
            }
        }
        // Makes accents dark plum.
        .tint(.cozyBrown)
        // Keeps light mode on so the text stays readable.
        .preferredColorScheme(.light)
    }

    // Deletes from the filtered list, since that's what is on screen.
    private func deleteItems(at offsets: IndexSet) {
        let shownItems = filteredItems
        for index in offsets {
            modelContext.delete(shownItems[index])
        }
    }
}

// A rounded filter button: dark when selected, outlined when not.
private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(
                    Capsule().fill(isSelected ? Color.cozyBrown : Color.clear)
                )
                .overlay(
                    // Thin outline on chips that aren't selected.
                    Capsule().stroke(
                        isSelected ? Color.clear : Color.secondary.opacity(0.3),
                        lineWidth: 1
                    )
                )
        }
        // Stops iOS from adding its default button styling.
        .buttonStyle(.plain)
        // Tells VoiceOver which chip is selected.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// One row in the pantry list: countdown cube on the left, item details next to it.
struct PantryRow: View {
    // The grocery item this row displays.
    let item: PantryItem

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
        HStack(spacing: 14) {
            // Countdown cube, tinted with the item's urgency color.
            VStack(spacing: 0) {
                Text(countdownNumber)
                    .font(.title2.bold())
                Text(countdownLabel)
                    .font(.caption2.bold())
            }
            .foregroundStyle(Color.cozyBrown)
            .frame(width: 64, height: 60)
            .background(
                item.urgency.color.opacity(0.35),
                in: RoundedRectangle(cornerRadius: 14)
            )
            // Reads the cube as one phrase, like "7 days left".
            .accessibilityElement(children: .combine)

            // Item name and details, stacked on the left.
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(Color.cozyBrown)
                Text("\(item.storage.rawValue) · Qty \(item.quantity)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Pushes everything to the left.
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    PantryListView()
        .modelContainer(for: PantryItem.self, inMemory: true)
}
