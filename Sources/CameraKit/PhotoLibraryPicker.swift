//
//  PhotoLibraryPicker.swift
//  CameraKit
//
//  Created by Anvora on 02/07/2026.
//

import SwiftUI
import PhotosUI

/// A thin convenience around the native SwiftUI `PhotosPicker` that delivers the
/// selected photo as a ready-to-use `UIImage`.
///
/// ```swift
/// PhotoLibraryPicker { image in self.image = image } label: {
///     Label("Import", systemImage: "photo")
/// }
/// ```
public struct PhotoLibraryPicker<Label: View>: View {
    @State private var selection: PhotosPickerItem?
    private let onPick: (UIImage) -> Void
    private let label: () -> Label

    public init(onPick: @escaping (UIImage) -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.onPick = onPick
        self.label = label
    }

    public var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            label()
        }
        .onChange(of: selection) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onPick(image)
                }
            }
        }
    }
}
