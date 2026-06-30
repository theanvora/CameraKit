import AVFoundation
import UIKit
import Observation

/// Errors surfaced by `CameraModel`.
public enum CameraError: Error, Sendable {
    case unauthorized
    case configurationFailed
    case captureFailed
}

/// An `@Observable` AVFoundation camera controller (iOS 17+), modeled on Apple's
/// AVCam sample: a dedicated session queue, permission handling, tap-to-focus,
/// pinch-to-zoom, torch, and modern rotation via `RotationCoordinator`.
///
/// Requires `NSCameraUsageDescription` in Info.plist.
@MainActor
@Observable
public final class CameraModel {
    public enum FlashMode: Sendable { case off, on, auto }

    // Observable state
    public private(set) var isConfigured = false
    public private(set) var isRunning = false
    public private(set) var position: AVCaptureDevice.Position = .back
    public private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    public private(set) var zoomFactor: CGFloat = 1
    public private(set) var minZoomFactor: CGFloat = 1
    public private(set) var maxZoomFactor: CGFloat = 1
    public private(set) var isTorchOn = false
    public private(set) var error: CameraError?
    public var flashMode: FlashMode = .auto

    /// The session to feed into `CameraPreview`.
    nonisolated(unsafe) public let session = AVCaptureSession()

    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private var videoInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var captureDelegate: PhotoCaptureDelegate?
    @ObservationIgnored private let queue = DispatchQueue(label: "com.anvora.camerakit.session")

    // Rotation (iOS 17 RotationCoordinator)
    @ObservationIgnored private weak var previewLayer: AVCaptureVideoPreviewLayer?
    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored private var rotationObservations: [NSKeyValueObservation] = []
    @ObservationIgnored private var captureRotationAngle: CGFloat = 90

    public init() {}

    // MARK: - Authorization

    @discardableResult
    public func requestAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return granted
    }

    // MARK: - Lifecycle

    /// Request access (if needed) and build the session graph. Call once before `start()`.
    public func configure() async {
        if authorizationStatus == .notDetermined {
            _ = await requestAccess()
        }
        guard authorizationStatus == .authorized else {
            error = .unauthorized
            return
        }

        await withCheckedContinuation { continuation in
            queue.async { [self] in
                session.beginConfiguration()
                session.sessionPreset = .photo
                if let device = Self.device(for: position),
                   let input = try? AVCaptureDeviceInput(device: device),
                   session.canAddInput(input) {
                    session.addInput(input)
                    videoInput = input
                }
                if session.canAddOutput(photoOutput) {
                    photoOutput.maxPhotoQualityPrioritization = .quality
                    session.addOutput(photoOutput)
                }
                session.commitConfiguration()
                continuation.resume()
            }
        }

        if videoInput == nil {
            error = .configurationFailed
            return
        }
        updateZoomRange()
        isConfigured = true
    }

    public func start() {
        queue.async { [self] in
            guard !session.isRunning else { return }
            session.startRunning()
            Task { @MainActor in self.isRunning = true }
        }
    }

    public func stop() {
        queue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
            Task { @MainActor in self.isRunning = false }
        }
    }

    /// Wire the preview layer so rotation stays correct (call from `CameraPreview`).
    public func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        guard let device = videoInput?.device else { return }
        createRotationCoordinator(for: device, previewLayer: layer)
    }

    // MARK: - Capture

    public func capturePhoto() async -> UIImage? {
        guard isConfigured else { return nil }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = avFlashMode
        settings.photoQualityPrioritization = .quality
        let angle = captureRotationAngle

        return await withCheckedContinuation { continuation in
            let delegate = PhotoCaptureDelegate { [weak self] image in
                if image == nil { Task { @MainActor in self?.error = .captureFailed } }
                continuation.resume(returning: image)
            }
            captureDelegate = delegate
            queue.async { [self] in
                if let connection = photoOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    // MARK: - Controls

    public func switchCamera() {
        let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        queue.async { [self] in
            session.beginConfiguration()
            if let videoInput { session.removeInput(videoInput) }
            if let device = Self.device(for: newPosition),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
            }
            session.commitConfiguration()
            Task { @MainActor in
                self.position = newPosition
                self.updateZoomRange()
                if let device = self.videoInput?.device, let layer = self.previewLayer {
                    self.createRotationCoordinator(for: device, previewLayer: layer)
                }
            }
        }
    }

    /// Set zoom, clamped to the device's supported range.
    public func setZoom(_ factor: CGFloat) {
        queue.async { [self] in
            guard let device = videoInput?.device else { return }
            let clamped = max(device.minAvailableVideoZoomFactor, min(factor, device.maxAvailableVideoZoomFactor))
            try? device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            Task { @MainActor in self.zoomFactor = clamped }
        }
    }

    /// Tap-to-focus using a point in the preview layer's coordinate space.
    public func focus(atViewPoint point: CGPoint) {
        guard let previewLayer else { return }
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        queue.async { [self] in
            guard let device = videoInput?.device else { return }
            try? device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        }
    }

    public func setTorch(_ on: Bool) {
        queue.async { [self] in
            guard let device = videoInput?.device, device.hasTorch else { return }
            try? device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            Task { @MainActor in self.isTorchOn = on }
        }
    }

    // MARK: - Helpers

    private func updateZoomRange() {
        guard let device = videoInput?.device else { return }
        minZoomFactor = device.minAvailableVideoZoomFactor
        maxZoomFactor = min(device.maxAvailableVideoZoomFactor, 10)
        zoomFactor = device.videoZoomFactor
    }

    private func createRotationCoordinator(for device: AVCaptureDevice, previewLayer: AVCaptureVideoPreviewLayer) {
        rotationObservations.removeAll()
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator

        previewLayer.connection?.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        captureRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture

        rotationObservations.append(
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak previewLayer] _, change in
                guard let angle = change.newValue else { return }
                Task { @MainActor in previewLayer?.connection?.videoRotationAngle = angle }
            }
        )
        rotationObservations.append(
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                Task { @MainActor in self?.captureRotationAngle = angle }
            }
        )
    }

    private var avFlashMode: AVCaptureDevice.FlashMode {
        switch flashMode {
        case .off:  return .off
        case .on:   return .on
        case .auto: return .auto
        }
    }

    private static func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: position
        ).devices.first
    }
}

/// Bridges the photo-output callback into an `async` continuation.
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (UIImage?) -> Void
    init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}
