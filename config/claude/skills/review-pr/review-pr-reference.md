# PRレビュー詳細リファレンス

`/review-pr`コマンドの詳細ガイドライン。

## 出力フォーマット

```markdown
## レビュー結果

変更内容: X files (+XXX/-XXX lines) | CI: Pass/Fail
総合評価: X/10点

### 概要
PRの目的と変更内容を1-2文で要約。

### レビューステータス
- [ ] 変更要求（P0項目の修正後に再レビュー）
- [ ] 承認保留（質問への回答待ち）
- [ ] 承認（LGTM - マージ可能）

---

## P0: マージ前に必須
### [file:line] 問題の要約
問題: 何が問題か
修正案: 具体的な修正方法

## P1: 次のサイクルで対応
### [file:line] 問題の要約
問題: 何が問題か
修正案: 改善方法

## P2: いずれ修正
- [file:line] 簡潔な提案

## P3: 余裕があれば
- [file:line] 簡潔な提案

---

## 既存コメントへの補足（該当時のみ）
- [@reviewer file:line] 同意/異議の理由

## 良かった点（任意）
- [file:line] 良い実装の理由

## 注意事項（任意）
- Breaking Changes: なし/あり
- ロールバック: 容易/注意が必要
```

## コードレビューの目的

1. バグの早期発見 - 本番障害を防ぐダブルチェック
2. 品質の担保 - 将来を見据えた保守性・拡張性の確保
3. 情報共有 - チーム内での変更の周知と影響確認

## 優先度分類

### P0 (Blocking) - マージ前に必須
- セキュリティ脆弱性（認証/認可、SQLi、XSS、CSRF）
- データ損失リスク（削除、破壊的変更）
- 重大なバグ（クラッシュ、機能停止）
- APIの破壊的変更

### P1 (Urgent) - 次のサイクルで対応
- パフォーマンス問題（N+1クエリ、メモリリーク）
- 重要なエラーハンドリング不足
- テストカバレッジの欠如（重要な機能）

### P2 (Normal) - いずれ修正
- 設計上の改善（責務分離、拡張性）
- 保守性の向上（重複コード、複雑な関数）
- ドキュメント問題

### P3 (Low) - 余裕があれば
- 命名の改善
- コメントの追加・削除
- 軽微なリファクタリング

## レビュー観点チェックリスト

### セキュリティ（P0優先）
- 認証・認可ロジックの実装が適切か
- 入力検証が全てのエンドポイントで実装されているか
- 機密情報がハードコードされていないか
- SQLi、XSS、CSRFなどの脆弱性がないか

### パフォーマンス（P1優先）
- N+1クエリ問題がないか
- 非効率なアルゴリズムが使用されていないか
- キャッシュ戦略が適切か

### 正確性（P0-P1）
- PRの目的と実装内容が一致しているか
- エッジケースの処理が実装されているか
- エラーハンドリングが適切か

### 保守性・可読性（P2-P3）
- ファイル・モジュール分割が適切か
- 関数が単一の責務に集中しているか
- 重複コードがないか

### 過剰設計（P2-P3）
- YAGNI違反がないか（現時点で不要な抽象化・設定・拡張ポイント）
- 1箇所でしか使わないヘルパー・ユーティリティを作っていないか
- 将来の仮定に基づいた設計をしていないか（実需要のないインターフェース分離等）
- フレームワークや内部コードが保証する範囲を二重チェックしていないか

### テスト（P1-P2）
- 重要な機能に対するテストが実装されているか
- エッジケースのカバーがあるか
- テスト容易性が確保されているか

## 避けるべきレビュー

- 曖昧な指摘（何をどう改善するか不明）
- 理由なしの指摘
- このPRで導入されていない既存の問題
- 個人的好み（チーム合意がない主観的スタイル）
- 意見が分かれるスタイル（早期リターン vs ガード節など）

## 評価基準

- 10点: 完璧、ベストプラクティス完全準拠
- 8-9点: 軽微な改善のみ、即座にマージ可能
- 6-7点: いくつかの改善必要、大きな問題なし
- 4-5点: 重要な修正必要、再レビュー推奨
- 3点以下: 大幅な見直し必要、マージ不可

## 技術スタック別の観点

### フロントエンド
- パフォーマンス（バンドルサイズ、レンダリング効率）
- アクセシビリティ（WCAG準拠）
- レスポンシブデザイン、クロスブラウザ対応

### バックエンド
- API設計（RESTful/GraphQL原則）
- エラーハンドリング（HTTPステータス、リトライ）
- データベース設計（正規化、インデックス）

### インフラ・DevOps
- リソース効率性（コスト最適化）
- 監視・ロギング
- セキュリティ設定（IAM、ネットワーク）

### Terraform PR の追加観点（destroy / IAM 変更時は必須）

terraform plan が destroy または IAM binding 変更を含む場合、以下を追加で確認する。

#### IAM binding の共有所有チェック（P0）

`google_*_iam_member` (non-authoritative) や AWS の non-authoritative IAM リソースが destroy される場合:

- **destroy 対象の `member` を抽出し、同じ `(project, role, member)` tuple が他 module / stack で管理されていないか grep で確認**
- 共有所有なら destroy で GCP/AWS 側の binding が消えて他 stack が drift する → P0 として指摘
- 確認コマンド例:
  ```bash
  grep -rn "<member 文字列の特徴的部分>" --include='*.tf' terraform/
  ```
- 特に注意するべき member パターン:
  - GCP default service agent (`service-{project_number}@gcp-sa-*.iam.gserviceaccount.com`) — 複数機能で共有されやすい
  - log sink writer identity (`unique_writer_identity = true` でも既存 sink は legacy default SA のままの drift がよくある)
  - GitHub Actions / Workload Identity 系の principal — 複数 stack で同じ principal を使う

#### unique_writer_identity の drift（P1）

`google_logging_project_sink.unique_writer_identity` を `true` に変更する PR では、既存 sink の writer identity は GCP API では rotate されない (新規作成時のみ反映)。

- terraform state では `true` だが GCP 上では legacy default SA のままという drift が発生
- 既存 sink を destroy → re-create するまで drift は解消しない
- レビュー時は `gcloud logging sinks describe <name>` で実 `writerIdentity` を確認するように促す

#### Cycle-aware な destroy 順序（P0-P1）

複数 stack にまたがる destroy では、上流 stack の destroy が下流 stack の依存リソース (IAM binding、Secret、Pub/Sub topic 等) を巻き込む可能性を確認する。

- 影響範囲が読み切れない場合は段階適用 (dev → stg → prd) を提案
- Drift 解消が apply の副作用として混入していないか plan を読み込む

## タイムボックス目安

- 小規模PR（<100行）: 10-15分
- 中規模PR（100-300行）: 20-30分
- 大規模PR（300行+）: 45-60分、または分割レビューを提案

## Reader Testing（大規模PR向け、任意）

300行以上の変更があるPRでは、Subagentに「先入観なしのレビュー」を委譲することで、著者バイアスによる見落としを検出できる。
自分がコードを書いた/読んだ後だと「見たいものしか見えない」ため、文脈ゼロのSubagentに読ませることに価値がある。

例外: 自分自身が subagent 内でこの skill を実行している（シンプルパスへのフォールバック中）場合、Reader Testing は発動しない。Agent tool の再帰呼び出し禁止のため。

```
Agent(subagent_type="general-purpose"):
  "このPRのdiffを読んで、以下の観点で問題を探してください。
   PRの説明や目的は意図的に伝えません。diffだけから判断してください。
   - 変更の意図が不明確な箇所
   - テストで検証されていないエッジケース
   - 暗黙の前提条件に依存している箇所"
```

Reader Testingの結果はステップ3の統合レビューに組み込む。

## 新規ディレクトリ作成時の追加チェック（必須）

PRで新規ディレクトリが作成されている場合、以下を確認：

### 1. ディレクトリ配置の妥当性

```bash
# 親ディレクトリの既存プロジェクト数を確認
ls {parent_directory}/ | wc -l

# 類似サービスの配置場所を検索
find terraform -type d -name "*keyword*" | head -10
```

- 親ディレクトリのプロジェクト数が2件以下 → 別の配置を検討すべき（P1）
- 類似サービスが別の場所にある → そちらに合わせるべき（P1）

### 2. ファイル分割パターンの確認

```bash
# 類似プロジェクトのファイル構成を確認
ls {similar_project}/common/
```

- main.tf に全リソースが入っている → リソース種別ごとに分割すべき（P2）
  - 例: pubsub.tf, logging.tf, firestore.tf, service_account.tf
