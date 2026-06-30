import SwiftUI
import VisionKit

/// Live text / barcode / QR scanning via VisionKit's `DataScannerViewController`.
/// Check `DataScannerView.isSupported` / `.isAvailable` before presenting; it only
/// runs on capable physical devices (not the Simulator).
///
/// ```swift
/// if DataScannerView.isSupported {
///     DataScannerView(recognizes: [.barcode(), .text()]) { items in
///         handle(items)
///     }
/// }
/// ```
@available(iOS 16.0, *)
public struct DataScannerView: UIViewControllerRepresentable {
    private let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>
    private let onTap: ([RecognizedItem]) -> Void

    public init(
        recognizes recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>,
        onTap: @escaping ([RecognizedItem]) -> Void
    ) {
        self.recognizedDataTypes = recognizedDataTypes
        self.onTap = onTap
    }

    /// Hardware supports data scanning.
    public static var isSupported: Bool { DataScannerViewController.isSupported }
    /// Supported *and* the user has granted camera access.
    public static var isAvailable: Bool { DataScannerViewController.isAvailable }

    public func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    public func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onTap: ([RecognizedItem]) -> Void
        init(onTap: @escaping ([RecognizedItem]) -> Void) { self.onTap = onTap }

        public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            onTap([item])
        }
    }
}
