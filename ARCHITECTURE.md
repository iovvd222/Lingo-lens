# ARCHITECTURE

カメラを向けるだけで、中央（またはタップ位置）の物体の英単語を1つ表示する語学学習アプリ。Lingo Lens (MIT) のフォーク。

## 技術構成
- SwiftUI / iOS 18+（Foundation Models 画像入力・PCC は iOS 27+ で実行時判定）
- カメラ: AVCaptureSession + AVCaptureVideoPreviewLayer（ARKit/ARラベル配置は廃止）。推論はプレビューと別キューで間引き実行（最大 ~4Hz、推論中のフレームは破棄）
- 永続化: Core Data（既存 SavedTranslation を軽量マイグレーションで拡張）
- 音声: AVSpeechSynthesizer（en-US の premium > enhanced > default を自動選択、事前ウォームアップ）

## 認識パイプライン
```
Camera frame ─▶ FrameThrottler ─▶ RegionSelector(中央 or タップ点) ─▶ ObjectRecognizer(protocol)
   ─▶ LabelNormalizer(label_map.json で学習語に正規化、未収録ラベルは捨てる)
   ─▶ RecognitionStabilizer(直近Nフレームの多数決・ヒステリシス・世代ID) ─▶ UI(単語1件)
```
- `ObjectRecognizer` 実装: `VisionClassifierRecognizer`(VNClassifyImageRequest, 1303ラベル, 追加容量0) / `FastViTRecognizer`(既存 ImageNet-1k Core ML) / `FoundationModelsRecognizer`(iOS 27, on-device, @Generable) / `PCCRecognizer`(iOS 27, entitlement 必須) / `MockRecognizer`(テスト)
- `RecognizerRouter` が実行時の可用性と評価結果から主認識器を自動選択し、失敗・タイムアウト・上限到達時は次順位へフォールバック。ユーザーには選ばせない。
- タップ時: タップ点を中心とした正方形ROI。iOS 17+ では VNGenerateForegroundInstanceMaskRequest の instanceAtPoint で対象の外接矩形に補正（失敗時は固定ROI）。
- 非同期: 各リクエストに単調増加の世代IDを付け、現在の世代より古い結果は破棄。

## 学習データ（Lexicon）
- `Lingo lens/Lingo lens/Resources/Lexicon/lexicon.json`: 単語ごとに ja / ipa / pos / collocations(3, en+ja) / examples(en+ja)。認識語彙に限定した自作データ（本プロジェクトの著作物）。IPA は CMUdict（BSD系）との照合で検証。
- `label_map.json`: 認識器ラベル → 学習語。`{"vision": {...}, "imagenet": {...}}`。抽象・学習価値の低いラベル（"structure","outdoor" 等）は収録しない＝表示しない。
- 取得順: lexicon.json → キャッシュ → (iOS 27 かつ AFM 可用時のみ) AFM 生成をキャッシュ保存。訳語の最終フォールバックは Translation framework。

## スキーマ
```json
{"word":"mug","ja":"マグカップ","ipa":"/mʌɡ/","pos":"noun",
 "collocations":[{"en":"a mug of coffee","ja":"マグカップ1杯のコーヒー"}],
 "examples":[{"en":"She poured tea into a mug.","ja":"彼女はマグカップに紅茶を注いだ。"}]}
```
