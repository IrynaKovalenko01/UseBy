import Foundation

// Tyler Todd

enum ExpiryEstimation {
    /// Whether FoodKeeper provides a positive numeric shelf-life value for the
    /// selected storage location. If not, estimate() uses its 7-day fallback.
    static func hasUsableShelfLife(for entry: FoodKeeperEntry, storage: StorageLocation) -> Bool {
        let location: String
        switch storage {
        case .fridge: location = "Refrigerate"
        case .freezer: location = "Freeze"
        case .pantry: location = "Pantry"
        }

        let prefixes = [location, "DOP_" + location]
        for prefix in prefixes {
            guard let amountText = entry.rawFields[prefix + "_Min"],
                  let amount = Int(amountText),
                  amount > 0,
                  let metric = entry.rawFields[prefix + "_Metric"]?.lowercased()
            else { continue }

            if ["day", "days", "week", "weeks", "month", "months", "year", "years"].contains(metric) {
                return true
            }
        }
        return false
    }

    // Estimates an expiration date or leaves it 
    // default if FoodKeeper can't access/doesn't have it
    static func estimate
        // for each entry check storage location
        (for entry: FoodKeeperEntry,
        storage: StorageLocation,
        from start: Date = .now) -> Date{
        var location = ""
        var numDaysLeft: Int = 7
        if (storage == .fridge){
            location = "Refrigerate"
        } else if (storage == .freezer){
            location = "Freeze"
        } else if (storage == .pantry){
            location = "Pantry"
        }

        var minShelfLife = ""
        var timeFrame = ""

        // certain fields have default shelf life while others run off the date of purpchase so
        // we'll check and parse like this

        // here's the check when we have the minimum time frame on hand
        if let text = entry.rawFields[location + "_Min"]{
            minShelfLife = text
            if let time = entry.rawFields[location + "_Metric"]{
                timeFrame = time
            }
        // here's when we only have the DOP availible
        } else if let text = entry.rawFields["DOP_" + location + "_Min"]{
            minShelfLife = text
            if let time = entry.rawFields["DOP_" + location + "_Metric"]{
                timeFrame = time
            }
        }

        // turn the number + time into days, weeks, months or years
        if let amount = Int(minShelfLife) {
            if amount > 0 {
                if  timeFrame == "Days" || timeFrame == "Day" {
                    numDaysLeft = amount
                } else if timeFrame == "Weeks" || timeFrame == "Week" {
                    numDaysLeft = amount * 7
                } else if timeFrame == "Months" || timeFrame == "Month" {
                    numDaysLeft = amount * 30
                } else if timeFrame == "Years" || timeFrame == "Year" {
                    numDaysLeft = amount * 365
                }
                // anything else is default
            }
        }

        // add the days to the start date
        var expiry = start
        if let date = Calendar.current.date(byAdding: .day, value: numDaysLeft, to: start) {
            expiry = date
        }
        return expiry
    }
}