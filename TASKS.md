# TASKS

| ID | Phase | タスク | 依存 | 状態 |
|---|---|---|---|---|
| T1 | 1 | リポジトリ取得・調査・Simulatorビルド | - | DONE |
| T2 | 2 | AVCapture化・認識器protocol・中央認識・単語1件表示・タップ選択・安定化 | T1 | TODO |
| T3 | 2 | ~~静的辞書~~ → AFM 生成 + キャッシュに変更（T4に統合） | - | DROPPED |
| T4 | 3 | 詳細ボトムシート・発音（単語/コロケーション/例文）・単語帳保存/閲覧 | T2,T3 | TODO |
| T5 | 1 | テストターゲット作成・モック・単体テスト | T2 | TODO |
| T6 | 4 | ChatGPTログイン / PCC バックエンド（調査中。protocol のみ先行） | T2 | TODO |
| T7 | 4 | 認識器比較評価（評価画像セット、精度/速度） | T2,T3 | TODO |
| T8 | 5 | UI品質（ダークモード/Dynamic Type/VoiceOver/権限拒否/空状態） | T4 | TODO |
| T9 | 6 | 公開準備（Bundle ID/名称/アイコン/Privacy/メタデータ/スクショ/Release設定） | T4 | TODO |

次: T2+T4+T5 を一括実装（AFM 主・Vision フォールバック）。
