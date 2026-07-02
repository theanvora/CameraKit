//
//  CameraView.swift
//  CameraKit
//
//  Created by Anvora on 02/07/2026.
//

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

    @State private var focusIndicator: CGPoint?

    public var body: some View {
        ZStack {
            GeometryReader { proxy in
                CameraPreview(session: model.session) { layer in
                    model.attachPreview(layer)
                }
                .ignoresSafeArea()
                .gesture(zoomGesture)
                .onTapGesture { location in
                    model.focus(atViewPoint: location)
                    showFocusIndicator(at: location)
                }
                .overlay(alignment: .topLeading) { focusReticle }
            }

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

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                model.setZoom(model.zoomFactor * value)
            }
    }

    @ViewBuilder
    private var focusReticle: some View {
        if let point = focusIndicator {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.yellow, lineWidth: 1.5)
                .frame(width: 72, height: 72)
                .position(point)
                .transition(.opacity)
        }
    }

    private func showFocusIndicator(at point: CGPoint) {
        withAnimation { focusIndicator = point }
        Task {
            try? await Task.sleep(for: .seconds(1))
            withAnimation { focusIndicator = nil }
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                model.flashMode = next(model.flashMode)
            } label: {
                Image(systemName: flashIcon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.4), in: Circle())
            }
            Button {
                model.setTorch(!model.isTorchOn)
            } label: {
                Image(systemName: model.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.4), in: Circle())
            }
            Spacer()
            if model.zoomFactor > 1.05 {
                Text(String(format: "%.1f×", model.zoomFactor))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.4), in: Capsule())
            }
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
