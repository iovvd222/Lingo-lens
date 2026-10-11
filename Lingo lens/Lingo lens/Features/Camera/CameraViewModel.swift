import AVFoundation
import Foundation
import FoundationModels
import SwiftUI

@MainActor
final class CameraViewModel: ObservableObject {
    @Published private(set) var cameraGranted = false
    @Published private(set) var permissionResolved = false
    @Published private(set) var word: String?
    @Published private(set) var selectedTarget = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var modelStatusMessage: String?
    @Published var isShowingDetails = false
    @Published var selectedWord: String?
    @Published private(set) var prefetchedEntry: WordEntry?

    let capture: CameraRecognitionController
    let lexicon: any LexiconProvider
    let speech = SpeechPlayer()
    private let repository: SavedWordRepository

    init(
        capture: CameraRecognitionController = CameraRecognitionController(router: RecognizerRouter(recognizers: [FoundationModelsRecognizer(), VisionClassifierRecognizer()])),
        lexicon: any LexiconProvider = FoundationModelsLexiconProvider(),
        repository: SavedWordRepository? = nil
    ) {
        self.capture = capture
        self.lexicon = lexicon
        self.repository = repository ?? SavedWordRepository(context: PersistenceController.shared.container.viewContext)
        capture.onWordUpdate = { [weak self] word in
            Task { @MainActor in self?.receive(word) }
        }
        capture.onSetupError = { [weak self] message in
            Task { @MainActor in self?.statusMessage = message }
        }

        switch SystemLanguageModel.default.availability {
        case .available:
            modelStatusMessage = nil
        case .unavailable(.deviceNotEligible), .unavailable(.appleIntelligenceNotEnabled):
            modelStatusMessage = "この端末では Apple Intelligence を利用できません。画像分類で認識します。"
        case .unavailable(.modelNotReady):
            modelStatusMessage = "Apple Intelligence のモデルを準備できません。画像分類で認識します。"
        @unknown default:
            modelStatusMessage = "Apple Intelligence を利用できません。画像分類で認識します。"
        }
    }

    func start() async {
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        let granted: Bool
        switch authorization {
        case .authorized:
            granted = true
        case .notDetermined:
            granted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            granted = false
        }
        cameraGranted = granted
        permissionResolved = true
        if granted {
            capture.resume()
        } else {
            statusMessage = "カメラへのアクセスを許可すると、物体を認識できます。"
        }
    }

    func selectTarget(at point: CGPoint) {
        selectedTarget = true
        word = nil
        prefetchedEntry = nil
        capture.selectTarget(at: point)
    }

    func openDetails() {
        guard let word else { return }
        selectedWord = word
        speech.speak(word)
        capture.pauseForDetails(true)
        isShowingDetails = true
    }

    func closeDetails() {
        isShowingDetails = false
        capture.pauseForDetails(false)
    }

    func stopCamera() {
        capture.stop()
    }

    private func receive(_ newWord: String?) {
        guard newWord != word else { return }
        word = newWord
        prefetchedEntry = nil
        guard let newWord else { return }
        Task {
            if let entry = try? await lexicon.entry(for: newWord), word == newWord {
                prefetchedEntry = entry
            }
        }
    }
}
