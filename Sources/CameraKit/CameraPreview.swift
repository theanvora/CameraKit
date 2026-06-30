import SwiftUI
import AVFoundation

/// SwiftUI host for an `AVCaptureVideoPreviewLayer`.
public struct CameraPreview: UIViewRepresentable {
    private let session: AVCaptureSession
    private let onMakeLayer: ((AVCaptureVideoPreviewLayer) -> Void)?

    public init(session: AVCaptureSession, onMakeLayer: ((AVCaptureVideoPreviewLayer) -> Void)? = nil) {
        self.session = session
        self.onMakeLayer = onMakeLayer
    }

    public func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        onMakeLayer?(view.videoPreviewLayer)
        return view
    }

    public func updateUIView(_ uiView: PreviewView, context: Context) {}

    public final class PreviewView: UIView {
        public override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
