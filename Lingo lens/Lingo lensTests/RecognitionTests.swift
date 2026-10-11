import CoreGraphics
import Foundation
import XCTest
@testable import Lingo_lens

final class RecognitionTests: XCTestCase {
    func testStabilizerRequiresRepeatedResultAndRejectsOldGeneration() {
        var stabilizer = RecognitionStabilizer()
        let firstGeneration = stabilizer.beginGeneration()
        XCTAssertNil(stabilizer.accept("lamp", generation: firstGeneration))
        XCTAssertEqual(stabilizer.accept("lamp", generation: firstGeneration), "lamp")

        let secondGeneration = stabilizer.beginGeneration()
        XCTAssertNil(stabilizer.accept("chair", generation: firstGeneration))
        XCTAssertNil(stabilizer.accept("chair", generation: secondGeneration))
        XCTAssertEqual(stabilizer.accept("chair", generation: secondGeneration), "chair")
    }

    func testRouterUsesNextRecognizerWhenEarlierRecognizerHasNoResult() async throws {
        let router = RecognizerRouter(recognizers: [
            MockRecognizer(result: nil),
            MockRecognizer(result: "cup")
        ])
        let result = try await router.recognize(testImage())
        XCTAssertEqual(result, "cup")
    }

    func testRouterFallsBackAfterRecognizerThrows() async throws {
        let router = RecognizerRouter(recognizers: [
            MockRecognizer(result: nil, shouldThrow: true),
            MockRecognizer(result: "book")
        ])
        let result = try await router.recognize(testImage())
        XCTAssertEqual(result, "book")
    }

    func testTapROIUsesSquareAroundTapAndClampsAtEdge() {
        let center = TapROI.square(around: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(center.rect.minX, 0.33, accuracy: 0.000_001)
        XCTAssertEqual(center.rect.minY, 0.33, accuracy: 0.000_001)
        XCTAssertEqual(center.rect.width, 0.34, accuracy: 0.000_001)
        XCTAssertEqual(center.rect.height, 0.34, accuracy: 0.000_001)

        let edge = TapROI.square(around: CGPoint(x: 0.02, y: 0.97))
        XCTAssertEqual(edge.rect.minX, 0)
        XCTAssertEqual(edge.rect.maxY, 1, accuracy: 0.000_001)
        XCTAssertEqual(edge.rect.width, edge.rect.height, accuracy: 0.000_001)
    }

    func testWordValidationRejectsMultipleWords() {
        XCTAssertEqual(WordValidation.normalize(" Lamp "), "lamp")
        XCTAssertNil(WordValidation.normalize("coffee cup"))
    }

    private func testImage() -> CGImage {
        let bytes = Data([0, 0, 0, 255]) as CFData
        let provider = CGDataProvider(data: bytes)!
        return CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}
