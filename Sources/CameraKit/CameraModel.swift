import AVFoundation
import UIKit
import Observation

/// An `@Observable` AVFoundation camera controller (iOS 17+). Owns the capture
/// session, exposes observable state for SwiftUI, and captures photos via
/// `async/await`. Configuration and session control run on a private queue.
///
/// Requires `NSCameraUsageDescription` in Info.plist.
@MainActor
@Observable
public final class CameraModel {
    public enum FlashMode: Sendable { case off, on, auto }

    public private(set) var isConfigured = false
    public private(set) var isRunning = false
    public private(set) var position: AVCaptureDevice.Position = .back
    public var flashMode: FlashMode = .auto

    /// The session to feed into `CameraPreview`.
    nonisolated(unsafe) public let session = AVCaptureSession()

    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private var videoInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var captureDelegate: PhotoCaptureDelegate?
    @ObservationIgnored private let queue = DispatchQueue(label: "com.anvora.camerakit.session")

    public init() {}

    /// Build the session graph (input + photo output). Call once before `start()`.
    public func configure() async {
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
                    session.addOutput(photoOutput)
                }
                session.commitConfiguration()
                continuation.resume()
            }
        }
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

    /// Capture a still photo. Returns `nil` if capture failed.
    public func capturePhoto() async -> UIImage? {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = avFlashMode
        return await withCheckedContinuation { continuation in
            let delegate = PhotoCaptureDelegate { image in
                continuation.resume(returning: image)
            }
            captureDelegate = delegate
            queue.async { [self] in
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    /// Flip between front and back cameras.
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
            Task { @MainActor in self.position = newPosition }
        }
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
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera],
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
