# UseBy — Never Let Food Go to Waste

UseBy is an iPhone app that helps students and people in shared apartments use their food before it expires. Scan a grocery barcode, and UseBy fills in an estimated expiration date from USDA shelf-life data, reminds you before the item goes bad, and suggests recipes ranked by what's expiring soonest.

📄 **Living Document:** https://docs.google.com/document/d/1Wj61WjFDm5TRLiOZKD9-bY41K7WJUOSo-l7MK2vbJMk/edit?usp=sharing

## Goals

- **Low-effort tracking:** Add groceries by scanning barcodes, with manual entry as a fallback.
- **Automatic expiration estimates:** Estimate expiration dates from USDA FoodKeeper shelf-life data, so users don't type dates.
- **Expiration reminders:** Notify users before items expire.
- **Use-it-first recipes:** Suggest recipes ranked by how soon their ingredients expire.
- **Less food waste:** Help users use groceries before they go bad and save money.

## Team

| Name | Role |
|------|------|
| Iryna Kovalenko | UX/UI Design & Frontend |
| Mohd Ramzan | Backend (API integrations, category mapping) |
| Alex Kuznetsov | Backend & Frontend (data layer) |
| Vaibhav Paranji | Frontend (barcode scan flow) |
| Mikkel Serrantes | Frontend (pantry view, notifications) |
| Tyler Todd | Backend & Frontend (CI, cooking mode) |

## Repository Layout

```
UseBy/
├── UseBy/                     # App source code
│   ├── Models/                # Data models (PantryItem)
│   ├── Views/                 # SwiftUI screens
│   ├── ContentView.swift      # Main tab view
│   └── UseByApp.swift         # App entry point
├── UseByTests/                # Unit tests (run by CI)
├── UseByUITests/              # UI tests (run locally)
├── UseBy.xcodeproj/           # Xcode project + shared scheme
├── .github/workflows/ci.yml   # CI: runs unit tests on every PR
├── coding-guidelines.md       # Style guide and Git workflow
├── README.md                  # Project overview, setup, and testing guide
└── .gitignore                 # Files Git should not track
```

## Tech Stack

Swift and SwiftUI, SwiftData for on-device storage, VisionKit for barcode scanning, the Open Food Facts API for product lookup, USDA FoodKeeper data for shelf life, and the Spoonacular API for recipes.

## Testing

The tests you can create/use at your own leisure can be found in the "UseByTests" folder. We'll be using Swift Testing and the formatting is also available within that file but, we'll leave it here as well for an example. (See section "Test Example")

There are also UI tests but, they are well explained within the folder and the overall code is a bit broad to place here.

## How To Test Code Yourself

Open the UseBy project within Xcode. We recommend using the iPhone 17 simulator since that's what the CI uses but, that's up to you. Press, "command + U" or open the "Product" drop down menu and click test. No need to run a full app build every time.

When it's done press, "command + 6" to open your test navigator, green checkmark means you passed. X means a test has failed.

## Test Example

(all of this will be on a swift file, add to UseByTest itself or make a new file)

1. if you're creating a file start with these imports:

```swift
import Testing
import Foundation
@testable import UseBy
```

2. Here is how your function will look:

```swift
@Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

// Here is an apple example 
    @Test func appleSafe(){
         #expect(item(expiringIn: 8).urgency == .safe)
    }
```

3. Test on XCode and make sure it passes, then you can commit and open a PR. Just send a text if nobody has looked/approved yet.

## CI

Whenever you do a pull request to main the CI will begin running on whatever code you’re trying to merge.

Testing begins using a Mac on GitHub’s server side, not your own. It’ll begin downloading your code all on GitHub’s Mac server, build out the app, and run any unit tests we specify within our "UseByTests" folder.

Results of the test will be shown on pull request when it’s done. You’ll see a checkmark if everything is smooth otherwise you’ll get a X so I wouldn’t merge until any errors are resolved.
