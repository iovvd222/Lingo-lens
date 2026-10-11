import AVFoundation
import CoreImage
import CoreVideo
import Foundation
import FoundationModels
import Vision

protocol ObjectRecognizer: Sendable {
    var isAvailable: Bool { get }
    func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) async throws -> String?
}

enum ObjectRecognitionError: Error {
    case noRecognizerAvailable
}

@Generable
struct GeneratedObjectWord {
    @Guide(description: "One common English noun in singular form. Return an empty string if no object can be identified.")
    var word: String
}

struct FoundationModelsRecognizer: ObjectRecognizer {
    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> String? {
        guard isAvailable else { return nil }
        let session = LanguageModelSession(instructions: "Identify the most prominent physical object in the image. Return exactly one common English noun in singular form. Do not return adjectives, explanations, or multiple words. If the image is unclear or has no identifiable object, return an empty string.")
        let response = try await session.respond(generating: GeneratedObjectWord.self, options: GenerationOptions(samplingMode: .greedy)) {
            "What is the main object in this image?"
            Attachment(image, orientation: orientation)
        }
        return WordValidation.normalize(response.content.word)
    }
}

struct VisionClassifierRecognizer: ObjectRecognizer {
    var isAvailable: Bool { true }

    func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> String? {
        try await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
            guard let label = request.results?.first(where: { $0.confidence >= 0.1 })?.identifier else {
                return nil
            }
            let firstLabel = label.split(separator: ",").first.map(String.init) ?? label
            return WordValidation.normalize(firstLabel.split(separator: " ").last.map(String.init) ?? firstLabel)
        }.value
    }
}

struct RecognizerRouter: ObjectRecognizer {
    let recognizers: [any ObjectRecognizer]

    var isAvailable: Bool { recognizers.contains(where: \.isAvailable) }

    func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> String? {
        var lastError: Error?
        for recognizer in recognizers where recognizer.isAvailable {
            do {
                if let word = try await recognizer.recognize(image, orientation: orientation), !word.isEmpty {
                    return word
                }
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        guard recognizers.contains(where: \.isAvailable) else {
            throw ObjectRecognitionError.noRecognizerAvailable
        }
        return nil
    }
}

struct MockRecognizer: ObjectRecognizer {
    let result: String?
    var isAvailable = true
    var shouldThrow = false

    func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> String? {
        if shouldThrow { throw ObjectRecognitionError.noRecognizerAvailable }
        return result
    }
}

enum WordValidation {
    static func normalize(_ value: String) -> String? {
        let word = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?:;\"'`“”()[]{}"))
        guard !word.isEmpty,
              word.count <= 32,
              word.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz-").contains($0) }),
              word.contains(where: { $0.isLetter }) else { return nil }
        return word
    }
}

struct TapROI: Equatable {
    let rect: CGRect

    static func square(around point: CGPoint, sideFraction: CGFloat = 0.34) -> TapROI {
        let side = min(max(sideFraction, 0.05), 1)
        let x = min(max(point.x - side / 2, 0), 1 - side)
        let y = min(max(point.y - side / 2, 0), 1 - side)
        return TapROI(rect: CGRect(x: x, y: y, width: side, height: side))
    }

    static let center = square(around: CGPoint(x: 0.5, y: 0.5))
}

enum CameraFrameCropper {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func image(from pixelBuffer: CVPixelBuffer, region: TapROI, tappedPoint: CGPoint? = nil) async -> CGImage? {
        if let tappedPoint, let selectedImage = await foregroundImage(from: pixelBuffer, at: tappedPoint) {
            return selectedImage
        }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let width = image.extent.width
        let height = image.extent.height
        let rect = CGRect(
            x: region.rect.minX * width,
            y: (1 - region.rect.maxY) * height,
            width: region.rect.width * width,
            height: region.rect.height * height
        ).integral.intersection(image.extent)
        guard !rect.isNull, rect.width > 1, rect.height > 1 else { return nil }
        return context.createCGImage(image.cropped(to: rect), from: rect)
    }

    private static func foregroundImage(from pixelBuffer: CVPixelBuffer, at point: CGPoint) async -> CGImage? {
        let handler = ImageRequestHandler(pixelBuffer)
        let request = GenerateForegroundInstanceMaskRequest()
        guard let observation = try? await handler.perform(request) else { return nil }
        let normalizedPoint = NormalizedPoint(
            x: min(max(point.x, 0), 0.999_999),
            y: 1 - min(max(point.y, 0), 0.999_999)
        )
        let instances = observation.instanceAtPoint(normalizedPoint)
        guard !instances.isEmpty,
              let maskedBuffer = try? observation.generateMaskedImage(
                for: instances,
                imageFrom: handler,
                croppedToInstancesExtent: true
              ) else { return nil }
        let maskedImage = CIImage(cvPixelBuffer: maskedBuffer)
        return context.createCGImage(maskedImage, from: maskedImage.extent)
    }
}
