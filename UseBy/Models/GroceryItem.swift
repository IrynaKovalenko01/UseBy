import Foundation

/// Vaibhav Paranji - 11/9/2026

/// The fields a pantry item and a shopping item have in common.
/// Both models conform, so one item can be compared directly to the other.
protocol GroceryItem {
    var name: String { get }
    var category: String { get }
    var storage: StorageLocation { get }
    var quantity: Int { get }
    var barcode: String? { get }
}

extension GroceryItem {
    /// Lowercased, trimmed name used for comparison.
    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// True when both items describe the same product:
    /// the same barcode, or else the same name.
    func isSameProduct<Other: GroceryItem>(as other: Other) -> Bool {
        if let a = barcode, let b = other.barcode, !a.isEmpty, a == b {
            return true
        }
        return !normalizedName.isEmpty && normalizedName == other.normalizedName
    }
}

// PantryItem already has every property the protocol needs.
extension PantryItem: GroceryItem {}