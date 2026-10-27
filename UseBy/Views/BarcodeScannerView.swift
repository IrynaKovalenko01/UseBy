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
            Group {
                // VisionKit data scanning requires supported hardware. A physical
                // device with Live Text support is needed; unsupported devices
                // receive an explanation instead of a nonfunctional camera view.
                if DataScannerViewController.isSupported {
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
                    .ignoresSafeArea()
                } else {
                    ContentUnavailableView(
                        "Barcode scanning isn't supported",
                        systemImage: "barcode.viewfinder",
                        description: Text("Use a device that supports Live Text scanning to scan a product barcode.")
                    )
                }
            }
            .navigationTitle("Scan Barcode")
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

        do {
            try scanner.startScanning()
        } catch {
            // This normally covers denied camera permission or a camera that
            // becomes unavailable; the parent turns it into a user-facing alert.
            context.coordinator.onError("Camera access is required to scan a barcode.")
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
