import SwiftUI
import VisionKit

/// SwiftUI wrapper for VisionKit's document camera (`VNDocumentCameraViewController`),
/// which provides edge detection, multi-page capture, and perspective correction.
///
/// ```swift
/// .sheet(isPresented: $scanning) {
///     DocumentScanner { pages in self.pages = pages }
/// }
/// ```
public struct DocumentScanner: UIViewControllerRepresentable {
    private let onComplete: ([UIImage]) -> Void
    private let onCancel: () -> Void
    private let onError: (Error) -> Void

    public init(
        onComplete: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void = {},
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onError = onError
    }

    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    public func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel, onError: onError)
    }

    public final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onComplete: ([UIImage]) -> Void
        private let onCancel: () -> Void
        private let onError: (Error) -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void, onError: @escaping (Error) -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
            self.onError = onError
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onComplete(pages)
        }

        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onError(error)
        }
    }
}
