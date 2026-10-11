import CoreGraphics
import Foundation
import FoundationModels
import XCTest
@testable import Lingo_lens

final class ModelCapabilityTests: XCTestCase {
    func testFoundationModelsCanProcessAnAttachedImageWhenAvailable() async throws {
        guard SystemLanguageModel.default.availability == .available else {
            throw XCTSkip("Foundation Models is unavailable on this test destination.")
        }

        let result = try await FoundationModelsRecognizer().recognize(sampleImage())
        XCTAssertTrue(result == nil || WordValidation.normalize(result ?? "") != nil)
        print("Foundation Models image input completed; recognized: \(result ?? "no object")")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = FoundationModelsLexiconProvider(cache: DiskWordEntryCache(directory: directory))
        let entry = try await provider.entry(for: "lamp")
        XCTAssertEqual(entry.word, "lamp")
        XCTAssertEqual(entry.collocations.count, 3)
        XCTAssertEqual(entry.examples.count, 2)
    }

    private func sampleImage() -> CGImage {
        let data = Data([32, 80, 160, 255]) as CFData
        let provider = CGDataProvider(data: data)!
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
