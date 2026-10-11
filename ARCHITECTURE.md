# ARCHITECTURE

カメラを向けるだけで、中央（またはタップ位置）の物体の英単語を1つ表示する語学学習アプリ。Lingo Lens (MIT) のフォーク。

## 技術構成
- SwiftUI / iOS 27+（Apple Intelligence 対応端末前提。AFM 非対応端末はサポートしない）
- カメラ: AVCaptureSession + AVCaptureVideoPreviewLayer（ARKit/ARラベル配置は廃止）。推論はプレビューと別キューで間引き実行（最大 ~4Hz、推論中のフレームは破棄）
- 永続化: Core Data（既存 SavedTranslation を軽量マイグレーションで拡張）
- 音声: AVSpeechSynthesizer（en-US の premium > enhanced > default を自動選択、事前ウォームアップ）

## 認識パイプライン
```
Camera frame ─▶ FrameThrottler(推論は常に1件のみ実行中) ─▶ RegionSelector(中央 or タップ点の切り出し)
   ─▶ ObjectRecognizer(protocol) ─▶ RecognitionStabilizer(世代ID・直近結果の安定化) ─▶ UI(単語1件)
```
- `ObjectRecognizer` 実装: `FoundationModelsRecognizer`(主。画像→@Generable で一般名詞1語) / `VisionClassifierRecognizer`(VNClassifyImageRequest。AFM 失敗・混雑時のフォールバック) / `ChatGPTRecognizer`・`PCCRecognizer`(将来。protocol だけ用意) / `MockRecognizer`(テスト)
- `RecognizerRouter` が可用性から自動選択し、失敗・タイムアウト時は次順位へ。ユーザーには選ばせない。
- タップ時: タップ点中心の正方形ROI。VNGenerateForegroundInstanceMaskRequest の instanceAtPoint で外接矩形に補正（失敗時は固定ROI）。
- 非同期: リクエストごとに世代IDを付け、古い世代の結果は破棄。

## 学習情報（WordEntry）
- `LexiconProvider`(protocol) → `FoundationModelsLexiconProvider` が @Generable `WordEntry`（ja / ipa / pos / collocations×3(en+ja) / examples(en+ja)）を生成。
- 生成結果は単語（小文字・単数形）をキーにディスクキャッシュし、同じ単語を再生成しない。ラベル表示時点で先読み生成する。
- 静的辞書は同梱しない（語彙を認識器に縛らないため）。
