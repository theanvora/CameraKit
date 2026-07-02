# CameraKit

A modern SwiftUI camera & scanning toolkit for iOS 26+. SwiftUI has no native
camera, so CameraKit wraps AVFoundation and VisionKit behind clean, `@Observable`,
`async/await` APIs.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/iOS-26%2B-blue.svg)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

## Features

- **Custom camera** — `CameraModel` (`@Observable` AVFoundation controller,
  modeled on Apple's AVCam) + `CameraPreview` + a ready-made `CameraView`.
  Includes **permission handling**, **pinch-to-zoom**, **tap-to-focus**, **torch**,
  flash, camera flip, correct rotation via `RotationCoordinator`, and
  `async` photo capture with `CameraError` reporting.
- **Document scanner** — `DocumentScanner` wraps VisionKit's
  `VNDocumentCameraViewController` (edge detection, multi-page, perspective
  correction) and returns `[UIImage]`. Ideal for PDF apps.
- **Live data scanning** — `DataScannerView` wraps `DataScannerViewController`
  for real-time text / barcode / QR (with `isSupported` / `isAvailable` checks).
- **Library import** — `PhotoLibraryPicker` wraps the native `PhotosPicker` and
  hands back a `UIImage`.

## Installation

```swift
.package(url: "https://github.com/theanvora/CameraKit.git", from: "1.0.0")
```

Add the relevant Info.plist keys: `NSCameraUsageDescription` (camera & scanners).

## Usage

### Custom camera

```swift
import CameraKit

struct CaptureScreen: View {
    @State private var photo: UIImage?
    var body: some View {
        CameraView { image in photo = image }
    }
}
```

### Document scanner (PDF-style)

```swift
.sheet(isPresented: $scanning) {
    DocumentScanner { pages in
        self.scannedPages = pages   // [UIImage], one per page
    }
    .ignoresSafeArea()
}
```

### Live text / QR / barcode

```swift
if DataScannerView.isSupported {
    DataScannerView(recognizes: [.barcode(), .text()]) { items in
        handle(items)
    }
}
```

### Import from library

```swift
PhotoLibraryPicker { image in self.image = image } label: {
    Label("Import", systemImage: "photo")
}
```

## Requirements

- iOS 26.0+ · Swift 5.9+
- A physical device for the camera & `DataScannerView` (not the Simulator).

## License

MIT
