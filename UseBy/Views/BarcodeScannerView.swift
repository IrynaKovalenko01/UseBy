import SwiftUI
import VisionKit

/// Hosts the barcode-entry workflow in the Scan tab.
///
/// The workflow is intentionally two steps: VisionKit returns only a barcode
/// payload, so the person must still supply the pantry-specific name, quantity,
/// storage location, and expiry date in AddItemView. This view owns temporary
/// scan-session state; it does not persist data itself.
struct ScanProductView: View {
    /// Holds the most recently tapped payload until the add-item sheet closes.
    @State private var scannedBarcode = ""

    /// Controls the add-item sheet. Keeping this separate from the barcode lets
    /// the scanner remain visible behind the sheet and makes cancellation safe.
    @State private var isPresentingAddItem = false

    /// Recreating this ID creates a fresh UIKit scanner and coordinator after a
    /// sheet closes, because the previous coordinator deliberately stopped its
    /// camera session after accepting one barcode.
    @State private var scannerSessionID = UUID()

    /// Stores a recoverable camera or VisionKit failure for the alert.
    @State private var scannerError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                // Large title that matches the My Kitchen header.
                Text("Scan Barcode")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.cozyBrown)

                // VisionKit data scanning requires supported hardware. A physical
                // device with Live Text support is needed; unsupported devices
                // receive an explanation instead of a nonfunctional camera view.
                if DataScannerViewController.isSupported {
                    // Explains the tap, since scanning alone doesn't add an item.
                    Text("Point your camera at a barcode, then tap its highlight.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    BarcodeScannerView(
                        onBarcode: { barcode in
                            // Accept a code only after the user taps its camera
                            // highlight, then collect the remaining pantry details.
                            scannedBarcode = barcode
                            isPresentingAddItem = true
                        },
                        onError: { scannerError = $0 }
                    )
                    .id(scannerSessionID)
                    // Shows the camera as a rounded card.
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.bottom, 8)
                } else {
                    // Pushes the card toward the middle of the screen.
                    Spacer()

                    // Card explaining why the camera isn't available.
                    VStack(spacing: 12) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.cozyBrown)
                        Text("Barcode scanning isn't supported")
                            .font(.system(.title2, design: .default, weight: .bold))
                        Text("Use a device that supports Live Text scanning to scan a product barcode.")
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            // Puts the warm cream color behind the whole screen.
            .background(Color.cozyCream)
            .navigationTitle("Scan Barcode")
            // Hides the default top bar because this screen has its own title.
            .toolbar(.hidden, for: .navigationBar)
            // Present the same form as manual entry, but attach the recognized
            // payload so AddItemView writes it to PantryItem.barcode.
            .sheet(isPresented: $isPresentingAddItem, onDismiss: resetScanner) {
                AddItemView(scannedBarcode: scannedBarcode)
            }
            // Scanner start and availability errors are visible rather than
            // silently leaving a blank camera screen.
            .alert("Unable to Scan", isPresented: Binding(
                get: { scannerError != nil },
                set: { if !$0 { scannerError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scannerError ?? "")
            }
        }
    }

    /// Clears one scan's transient data and forces a new VisionKit controller
    /// for the next scan, whether the form was saved or cancelled.
    private func resetScanner() {
        scannedBarcode = ""
        scannerSessionID = UUID()
    }
}

/// Bridges VisionKit's UIKit camera controller into SwiftUI.
///
/// A recreation needs this representable because DataScannerViewController is a
/// UIKit type. It recognizes barcode data only, asks VisionKit to show its
/// standard camera guidance and highlights, and reports events upward through
/// closures so the parent controls presentation and persistence.
///
/// The app target must provide NSCameraUsageDescription in its generated
/// Info.plist, and scanning must be tested on supported physical hardware.
struct BarcodeScannerView: UIViewControllerRepresentable {
    /// Sends the selected barcode payload to the SwiftUI owner.
    let onBarcode: (String) -> Void

    /// Sends camera startup and availability failures to the SwiftUI owner.
    let onError: (String) -> Void

    /// UIKit holds delegates weakly. SwiftUI retains this coordinator for the
    /// representable's lifetime, so it safely receives scanner callbacks.
    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode, onError: onError)
    }

    /// Builds and starts VisionKit's live camera scanner.
    ///
    /// Barcode recognition accepts all barcode symbologies. The user taps a
    /// highlighted result to confirm it; scanning a product never inserts an
    /// item automatically. balanced quality is a general-purpose tradeoff
    /// between recognition speed and resolution.
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator

        // Keeps a reference to the coordinator for use inside the delayed task.
                let coordinator = context.coordinator

                // Waits briefly so the camera view is on screen before scanning starts.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))

                    do {
                        try scanner.startScanning()
                    } catch {
                        // This normally covers denied camera permission or a camera that
                        // becomes unavailable; the parent turns it into a user-facing alert.
                        coordinator.onError("Camera access is required to scan a barcode.")
                    }
                }
        return scanner
    }

    /// Configuration is immutable for one session. A new session is created by
    /// changing ScanProductView.scannerSessionID after the form closes.
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    /// Converts UIKit delegate events into the simple SwiftUI callbacks above.
    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        let onError: (String) -> Void

        /// Prevents several rapid taps from presenting more than one add sheet.
        private var hasScannedBarcode = false

        init(onBarcode: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
            self.onError = onError
        }

        /// Handles the user's explicit tap on a highlighted barcode.
        ///
        /// The scanner stops before invoking the callback so the camera does not
        /// keep producing results while SwiftUI presents the manual-details form.
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard case let .barcode(barcode) = item,
                  let value = barcode.payloadStringValue,
                  !hasScannedBarcode else {
                return
            }

            hasScannedBarcode = true
            dataScanner.stopScanning()
            onBarcode(value)
        }

        /// Reports a session that becomes unavailable after it has started.
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: Error) {
            onError(error.localizedDescription)
        }
    }
}
