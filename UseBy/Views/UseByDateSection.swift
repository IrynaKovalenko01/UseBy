import SwiftUI

private enum ExpiryDateMethod: String, CaseIterable, Identifiable {
    case manual = "Enter manually"
    case estimated = "Estimate from FoodKeeper"

    var id: String { rawValue }
}

/// Reusable Use By control shared by the Add and Edit forms.
struct UseByDateSection: View {
    @Binding var expiryDate: Date
    @Binding var canSave: Bool

    let itemName: String
    let storage: StorageLocation

    @State private var method: ExpiryDateMethod = .manual
    @State private var manualDate: Date
    @State private var estimatedDate: Date?
    @State private var isLoading = false
    @State private var statusMessage: String?

    init(
        expiryDate: Binding<Date>,
        canSave: Binding<Bool>,
        itemName: String,
        storage: StorageLocation
    ) {
        self._expiryDate = expiryDate
        self._canSave = canSave
        self.itemName = itemName
        self.storage = storage
        self._manualDate = State(initialValue: expiryDate.wrappedValue)
    }

    private var estimationTaskKey: String {
        "\(method.rawValue)|\(itemName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(storage.rawValue)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Use By method", selection: $method) {
                ForEach(ExpiryDateMethod.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)

            if method == .manual {
                DatePicker("Use by", selection: $manualDate, displayedComponents: .date)
                    .onChange(of: manualDate) { _, newDate in
                        expiryDate = newDate
                    }
            } else {
                estimatedDateContent
            }
        }
        .onChange(of: method) { _, newMethod in
            if newMethod == .manual {
                expiryDate = manualDate
                canSave = true
                statusMessage = nil
            } else {
                canSave = false
                estimatedDate = nil
                statusMessage = nil
            }
        }
        .task(id: estimationTaskKey) {
            guard method == .estimated else { return }
            await loadEstimate()
        }
    }

    @ViewBuilder
    private var estimatedDateContent: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                Text("Finding an estimate…")
                    .foregroundStyle(.secondary)
            }
        } else if let estimatedDate {
            LabeledContent("Estimated use by", value: estimatedDate.formatted(date: .abbreviated, time: .omitted))
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Based on USDA FoodKeeper storage guidance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("This is an estimate, not a guarantee of when the ingredient will expire. Check the food's condition before consuming.")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if let statusMessage {
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Enter an ingredient name to get an estimate.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func loadEstimate() async {
        let query = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            isLoading = false
            canSave = false
            statusMessage = "Enter an ingredient name before estimating."
            return
        }

        isLoading = true
        canSave = false
        statusMessage = nil
        defer { isLoading = false }

        do {
            if let entry = try await USDAFoodKeeperAPI.shared.bestMatch(for: query) {
                let hasShelfLife = ExpiryEstimation.hasUsableShelfLife(for: entry, storage: storage)
                let result = ExpiryEstimation.estimate(for: entry, storage: storage)
                guard !Task.isCancelled else { return }

                estimatedDate = result
                expiryDate = result
                canSave = true
                statusMessage = hasShelfLife ? nil : ExpiryEstimation.fallbackMessage(for: entry, storage: storage)
            } else {
                // A local product fallback keeps estimation usable when USDA
                // has no exact item match. The UI clearly labels the estimate.
                let result = ExpiryEstimation.estimate(for: query, storage: storage)
                guard !Task.isCancelled else { return }
                estimatedDate = result
                expiryDate = result
                canSave = true
                statusMessage = ExpiryEstimation.fallbackMessage(for: query, storage: storage)
            }
        } catch {
            // Network or decoding failures should not prevent a local estimate.
            // The fallback message makes clear that this is not USDA data.
            guard !Task.isCancelled else { return }
            let result = ExpiryEstimation.estimate(for: query, storage: storage)
            estimatedDate = result
            expiryDate = result
            canSave = true
            statusMessage = "FoodKeeper could not be reached. " + ExpiryEstimation.fallbackMessage(for: query, storage: storage)
        }
    }
}
