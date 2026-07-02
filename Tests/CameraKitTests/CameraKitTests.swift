//
//  CameraKitTests.swift
//  CameraKit
//
//  Created by Anvora on 02/07/2026.
//

import XCTest
@testable import CameraKit

@MainActor
final class CameraKitTests: XCTestCase {
    func testCameraModelInitialState() {
        let model = CameraModel()
        XCTAssertFalse(model.isConfigured)
        XCTAssertFalse(model.isRunning)
        XCTAssertEqual(model.position, .back)
        XCTAssertEqual(model.flashMode, .auto)
    }

    func testDataScannerSupportFlagIsQueryable() {
        // Just exercise the static flags (false on Simulator) without crashing.
        _ = DataScannerView.isSupported
    }
}

extension CameraModel.FlashMode: Equatable {}
