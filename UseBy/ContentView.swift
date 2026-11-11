import SwiftUI
import SwiftData

// The three screens the bottom bar switches between.
enum AppTab {
    case pantry
    case scan
    case cookbook
}

struct ContentView: View {
    // Which screen is showing. The app starts on Pantry.
    @State private var selectedTab: AppTab = .pantry

    var body: some View {
        // Shows the screen for the selected tab.
        Group {
            switch selectedTab {
            case .pantry:
                PantryListView()

            // ScanProductView owns the camera-to-add-form workflow. It is only
            // created while this tab is selected, so the camera turns off when
            // the person switches to another tab.
            case .scan:
                ScanProductView()

            case .cookbook:
                ComingSoonView(
                    title: "Cookbook",
                    heading: "Recipes are coming soon",
                    message: "We'll suggest recipes that use your soonest-expiring food first.",
                    icon: "book.closed"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Puts our custom bar at the bottom, so lists scroll above it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selectedTab: $selectedTab)
        }
        // Makes accents dark plum.
        .tint(.cozyBrown)
        // Keeps light mode on so the text stays readable.
        .preferredColorScheme(.light)
    }
}

// The bottom bar: Pantry on the left, a raised Scan button in the middle,
// and Cookbook on the right.
private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(alignment: .bottom) {
            TabBarItem(
                title: "Pantry",
                icon: "refrigerator",
                isSelected: selectedTab == .pantry
            ) {
                selectedTab = .pantry
            }

            // Raised center button for scanning.
            Button {
                selectedTab = .scan
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.cozyBrown, in: RoundedRectangle(cornerRadius: 20))
                        // Off-white ring around the button, like in the example.
                        .padding(5)
                        .background(Color.cozyCream, in: RoundedRectangle(cornerRadius: 25))
                        // Soft shadow so the button looks lifted.
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    Text("Scan")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedTab == .scan ? Color.cozyBrown : Color.secondary)
                }
                .frame(maxWidth: .infinity)
                // Negative padding lets the button stick up above the bar.
                .padding(.top, -24)
            }
            // Stops iOS from adding its default button styling.
            .buttonStyle(.plain)
            // Tells VoiceOver which tab is selected.
            .accessibilityAddTraits(selectedTab == .scan ? .isSelected : [])

            TabBarItem(
                title: "Cookbook",
                icon: "book.closed",
                isSelected: selectedTab == .cookbook
            ) {
                selectedTab = .cookbook
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, -18)
        // White bar with rounded top corners and a soft shadow.
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .fill(Color.cozyCard)
                        .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
                        // Extends the white down to the bottom edge of the screen.
                        .ignoresSafeArea(edges: .bottom)
                )
    }
}

// One regular tab: an icon with a small label underneath.
private struct TabBarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .default))
            }
            // Dark plum when selected, gray when not.
            .foregroundStyle(isSelected ? Color.cozyBrown : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        // Stops iOS from adding its default button styling.
        .buttonStyle(.plain)
        // Tells VoiceOver which tab is selected.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// A cozy placeholder for features that aren't ready yet.
struct ComingSoonView: View {
    let title: String
    let heading: String
    let message: String
    let icon: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                // Large title that matches the My Kitchen header.
                Text(title)
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.cozyBrown)

                // Pushes the card toward the middle of the screen.
                Spacer()

                // Card with the icon and coming soon message.
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 56))
                        .foregroundStyle(Color.cozyBrown)
                    Text(heading)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(28)
                .frame(maxWidth: .infinity)
                .background(Color.cozyCard, in: RoundedRectangle(cornerRadius: 20))

                // Keeps the card centered by balancing the space above it.
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            // Puts the off-white color behind the whole screen.
            .background(Color.cozyCream)
            // Hides the default top bar because this screen has its own title.
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PantryItem.self, inMemory: true)
}
