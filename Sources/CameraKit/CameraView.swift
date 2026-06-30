import SwiftUI

/// A ready-to-use camera screen: live preview with shutter, flash, and flip
/// controls. Hand it a closure to receive the captured image.
///
/// ```swift
/// CameraView { image in self.photo = image }
/// ```
public struct CameraView: View {
    @State private var model = CameraModel()
    private let onCapture: (UIImage) -> Void

    public init(onCapture: @escaping (UIImage) -> Void) {
        self.onCapture = onCapture
    }

    public var body: some View {
        ZStack {
            CameraPreview(session: model.session)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                shutterBar
            }
            .padding()
        }
        .task {
            await model.configure()
            model.start()
        }
        .onDisappear { model.stop() }
    }

    private var topBar: some View {
        HStack {
            Button {
                model.flashMode = next(model.flashMode)
            } label: {
                Image(systemName: flashIcon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.4), in: Circle())
            }
            Spacer()
        }
    }

    private var shutterBar: some View {
        HStack {
            Spacer()
            Button {
                Task {
                    if let image = await model.capturePhoto() { onCapture(image) }
                }
            } label: {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(.white.opacity(0.25)))
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button {
                model.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .padding(.trailing, 24)
        }
    }

    private var flashIcon: String {
        switch model.flashMode {
        case .off:  return "bolt.slash.fill"
        case .on:   return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        }
    }

    private func next(_ mode: CameraModel.FlashMode) -> CameraModel.FlashMode {
        switch mode {
        case .auto: return .on
        case .on:   return .off
        case .off:  return .auto
        }
    }
}
