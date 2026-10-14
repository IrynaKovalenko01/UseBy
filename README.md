# UseBy — Never Let Food Go to Waste

UseBy is an iPhone app that helps students and people in shared apartments use their food before it expires. Scan a grocery barcode, and UseBy fills in an estimated expiration date from USDA shelf-life data, reminds you before the item goes bad, and suggests recipes ranked by what's expiring soonest.

📄 **Living Document:** 

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
├── README.md        # Project overview, team, and repository layout
└── .gitignore       # Files Git should not track
```

## Tech Stack

Swift and SwiftUI, SwiftData for on-device storage, VisionKit for barcode scanning, the Open Food Facts API for product lookup, USDA FoodKeeper data for shelf life, and the Spoonacular API for recipes.
