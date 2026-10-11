# TASKS

| ID | Phase | タスク | 依存 | 状態 |
|---|---|---|---|---|
| T1 | 1 | リポジトリ取得・調査・Simulatorビルド | - | DONE |
| T2 | 2 | AVCapture化・認識器protocol・中央認識・単語1件表示・タップ選択・安定化 | T1 | TODO |
| T3 | 2 | ラベル→学習語マッピング・lexicon.json 作成（訳/IPA/コロケーション3/例文） | T1 | TODO |
| T4 | 3 | 詳細ボトムシート・発音（単語/コロケーション/例文）・単語帳保存/閲覧 | T2,T3 | TODO |
| T5 | 1 | テストターゲット作成・モック・単体テスト | T2 | TODO |
| T6 | 4 | FoundationModels / PCC 認識器（可用性判定・フォールバック・モック） | T2 | TODO |
| T7 | 4 | 認識器比較評価（評価画像セット、精度/速度） | T2,T3 | TODO |
| T8 | 5 | UI品質（ダークモード/Dynamic Type/VoiceOver/権限拒否/空状態） | T4 | TODO |
| T9 | 6 | 公開準備（Bundle ID/名称/アイコン/Privacy/メタデータ/スクショ/Release設定） | T4 | TODO |

次: T2 と T3 を並列着手。
