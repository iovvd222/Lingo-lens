import AVFoundation
import CoreImage
import Foundation

final class CameraRecognitionController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    private let router: RecognizerRouter
    private let setupQueue = DispatchQueue(label: "lingolens.camera.setup")
    private let frameQueue = DispatchQueue(label: "lingolens.camera.frames")
    private let output = AVCaptureVideoDataOutput()
    private var isConfigured = false
    private var isPaused = false
    private var isRecognizing = false
    private var lastFrameTime: TimeInterval = 0
    private var selectedRegion = TapROI.center
    private var selectedPoint: CGPoint?
    private var stabilizer = RecognitionStabilizer()

    var onWordUpdate: ((String?) -> Void)?
    var onSetupError: ((String) -> Void)?

    init(router: RecognizerRouter) {
        self.router = router
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: frameQueue)
    }

    func start() {
        setupQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                do {
                    try self.configureSession()
                    self.isConfigured = true
                } catch {
                    DispatchQueue.main.async { self.onSetupError?("カメラを準備できませんでした。") }
                    return
                }
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        frameQueue.async { [weak self] in
            guard let self else { return }
            self.isPaused = true
            self.stabilizer.beginGeneration(clearCurrent: false)
        }
        setupQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func resume() {
        frameQueue.async { [weak self] in
            guard let self else { return }
            self.isPaused = false
            self.stabilizer.beginGeneration(clearCurrent: false)
        }
        start()
    }

    func pauseForDetails(_ paused: Bool) {
        frameQueue.async { [weak self] in
            guard let self else { return }
            self.isPaused = paused
            self.stabilizer.beginGeneration(clearCurrent: false)
        }
    }

    func selectTarget(at devicePoint: CGPoint) {
        frameQueue.async { [weak self] in
            guard let self else { return }
            self.selectedRegion = TapROI.square(around: devicePoint)
            self.selectedPoint = devicePoint
            self.stabilizer.beginGeneration()
            DispatchQueue.main.async { self.onWordUpdate?(nil) }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard !isPaused, !isRecognizing, now - lastFrameTime >= 0.25,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isRecognizing = true
        lastFrameTime = now
        let generation = stabilizer.generation
        let region = selectedRegion
        let tappedPoint = selectedPoint
        let router = self.router
        let frameQueue = self.frameQueue
        Task { [weak self] in
            let image = await CameraFrameCropper.image(from: pixelBuffer, region: region, tappedPoint: tappedPoint)
            let result: String?
            if let image {
                result = try? await router.recognize(image, orientation: .right)
            } else {
                result = nil
            }
            frameQueue.async { [weak self] in
                guard let self else { return }
                self.isRecognizing = false
                let stableWord = self.stabilizer.accept(result ?? nil, generation: generation)
                DispatchQueue.main.async { self.onWordUpdate?(stableWord) }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraSetupError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw CameraSetupError.cannotConfigure
        }
        session.addInput(input)
        session.addOutput(output)
    }

    private enum CameraSetupError: Error {
        case noCamera
        case cannotConfigure
    }
}
