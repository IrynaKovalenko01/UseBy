import Foundation

// Tyler Todd

enum ExpiryEstimation{
    // Estimates an expiration date or leaves it 
    // default if FoodKeeper can't access/doesn't have it
    static func estimate
        // for each entry check storage location
        (for entry: FoodKeeperEntry,
        storage: StorageLocation,
        from start: Date = .now) -> Date{
        var shelfLife = ""
        var numDaysLeft: Int = 7
        if (storage == .fridge){
            if let text = entry.refrigerator {shelfLife = text}
        } else if (storage == .freezer){
            if let text = entry.freezer {shelfLife = text}
        } else if (storage == .pantry){
            if let text = entry.pantry {shelfLife = text}
        }

        // TODO: turn shelfLife into numDaysLeft

        // add the days to the start date
        var expiry = start
        if let date = Calendar.current.date(byAdding: .day, value: numDaysLeft, to: start) {
            expiry = date
        }
        return expiry
    }
}