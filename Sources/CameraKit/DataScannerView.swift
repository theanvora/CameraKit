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
public struct DataScannerView: UIViewControllerRepresentable {
    private let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>
    private let onTap: ([RecognizedItem]) -> Void
    private let onAdd: ([RecognizedItem]) -> Void

    /// - Parameters:
    ///   - recognizes: data types to detect (e.g. `[.barcode(), .text()]`).
    ///   - onAdd: newly recognized items as they stream in live.
    ///   - onTap: items the user tapped on.
    public init(
        recognizes recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>,
        onAdd: @escaping ([RecognizedItem]) -> Void = { _ in },
        onTap: @escaping ([RecognizedItem]) -> Void = { _ in }
    ) {
        self.recognizedDataTypes = recognizedDataTypes
        self.onAdd = onAdd
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
        Coordinator(onAdd: onAdd, onTap: onTap)
    }

    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onAdd: ([RecognizedItem]) -> Void
        private let onTap: ([RecognizedItem]) -> Void
        init(onAdd: @escaping ([RecognizedItem]) -> Void, onTap: @escaping ([RecognizedItem]) -> Void) {
            self.onAdd = onAdd
            self.onTap = onTap
        }

        public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            onTap([item])
        }

        public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            onAdd(addedItems)
        }
    }
}
