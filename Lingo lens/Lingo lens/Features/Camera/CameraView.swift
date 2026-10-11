import AVFoundation
import SwiftUI

struct CameraView: View {
    @StateObject private var model = CameraViewModel()
    @State private var previewLayer: AVCaptureVideoPreviewLayer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if model.cameraGranted {
                    CameraPreview(session: model.capture.session) { previewLayer = $0 }
                }

                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        if let message = model.modelStatusMessage {
                            statusCard(message)
                        }
                        if let message = model.statusMessage {
                            statusCard(message)
                        }
                    }
                    .padding(.top, 10)

                    Spacer()
                    Image(systemName: model.selectedTarget ? "scope" : "viewfinder")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                        .allowsHitTesting(false)
                    Text(model.selectedTarget ? "タップした場所を認識しています" : "画面の物体をタップして認識")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 7)
                        .allowsHitTesting(false)
                    Spacer()

                    if let word = model.word {
                        Button(action: model.openDetails) {
                            HStack(spacing: 10) {
                                Text(word.capitalized).font(.title2.weight(.semibold))
                                Image(systemName: "speaker.wave.2.fill").font(.subheadline)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        .accessibilityLabel("\(word) を発音して詳細を表示")
                        .padding(.bottom, 20)
                    } else if model.cameraGranted {
                        Text(model.selectedTarget ? "認識中…" : "中央の物体を探しています…")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.bottom, 24)
                    }
                }
                .padding(.horizontal, 18)

                if !model.permissionResolved {
                    ProgressView("カメラを準備しています…")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else if !model.cameraGranted {
                    permissionView
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .local).onEnded { value in
                    let inWordButton = value.location.y > geometry.size.height - 105
                        && abs(value.location.x - geometry.size.width / 2) < 150
                    guard !inWordButton, model.cameraGranted, !model.isShowingDetails else { return }
                    let point = previewLayer?.captureDevicePointConverted(fromLayerPoint: value.location)
                        ?? CGPoint(x: value.location.x / geometry.size.width, y: value.location.y / geometry.size.height)
                    model.selectTarget(at: point)
                }
            )
            .background(Color.black)
            .task { await model.start() }
            .onDisappear { model.stopCamera() }
            .sheet(isPresented: $model.isShowingDetails, onDismiss: model.closeDetails) {
                if let word = model.selectedWord {
                    WordDetailSheet(
                        word: word,
                        provider: model.lexicon,
                        repository: SavedWordRepository(context: PersistenceController.shared.container.viewContext),
                        speech: model.speech,
                        initialEntry: model.prefetchedEntry
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill").font(.system(size: 42))
            Text("カメラへのアクセスが必要です").font(.headline)
            Text("カメラ映像から身近な物の英単語を表示します。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("設定を開く") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .foregroundStyle(.white)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(28)
    }

    private func statusCard(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
