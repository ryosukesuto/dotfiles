## 役割分担

| ツール | 役割 |
|--------|------|
| Greptile | 既存コード一貫性・cross-repo文脈 |
| Claude Code | PR内ロジック・設計・セキュリティリスク |
| Checkov | 静的解析gating（IaC専用、P0 blockに一本化） |

Greptile を選ばない構成では、Claude Code が「PR内ロジック・設計・セキュリティリスク」に加えて「既存コードとの一貫性チェック（命名規則・既存パターンへの追従・cross-file 整合）」も兼任する。cross-repo 文脈は Claude Code 単独では補えないため、レビュー観点は同一リポ内に閉じた一貫性チェックに限定する。テンプレートは `{{CONSISTENCY_DELEGATION}}` 変数で 2 バリアントを切り替える。

## Greptile 料金改定と `triggerOnUpdates` 方針（2026-03〜）

2026-03 に Greptile の料金体系が変わり、実質 2〜3 倍に値上がりした。

- 改定前: レビューを受けたエンジニアアカウント数 × $30
- 改定後: 上記に加えて、1 アカウントあたり 50 件/月を超えたレビューは $1/件の追加課金

「1 件のレビュー」は Greptile がレビューを完了するごとにカウントされる。PR 作成時の初回レビュー、`triggerOnUpdates: true` 時のコミット追加レビュー、`@greptileai` 手動再実行いずれも個別に課金対象。`triggerOnUpdates: false` の節約効果は「PR の追加コミット数 × 件数」になる（活発な PR ほど効果大）。

これを受けて org レベルで Auto-review on new commits（`triggerOnUpdates`）が OFF に切り替えられた。PR 作成時のレビューは従来通り走るが、push 後の再レビューは手動トリガー（`@claude` 相当）に寄せる運用。

setup-ci-review の既定値:
- テンプレート（`config.json` / `config-iac.json`）は `triggerOnUpdates: false`
- `true` に上げるのは Tier 1 リポのみ（後述）
- `update-existing.sh` は既存 `triggerOnUpdates` 値を保持する（true 運用中のリポを勝手に false に戻さない）

新規 setup 時は step 2 の `greptileAutoReview` で `yes` を選んだ場合のみ、生成後に `sed -i '' 's/"triggerOnUpdates": false,/"triggerOnUpdates": true,/' .greptile/config.json` で書き換える。

## Tier 分類（Greptile 適用範囲の判定基準）

50 review/seat の枠と Claude Code Review の Phase 2（grep ベース一貫性チェック）の両立を踏まえ、リポを 3 tier に分類して Greptile 適用範囲を決める。Claude Code Review はどの Tier でも常に導入する。

| Tier | 対象 | Greptile | `triggerOnUpdates` |
|------|------|----------|---------------------|
| 1（重要・活発） | プロダクト中核・PR 頻度高・追加課金を払う価値があるリポ | 導入 | `true` |
| 2（重要・低〜中頻度） | プロダクト関連だが PR 頻度が低く、初回レビューだけで網が足りるリポ | 導入 | `false`（初回のみ） |
| 3（スクラッチ・experimental・Claude のみで足りるリポ） | 使い捨て・個人系・IaC scanner で重複機能をカバーできるリポ | 未導入（GitHub App から uninstall） | — |

判定の目安:
- Tier 1 にする条件: ops / server-config 相当。本番障害に直結し、PR ごとにコミット追加が頻繁で、`triggerOnUpdates: true` の追加課金を払う価値がある
- Tier 2 にする条件: 上記に当てはまらないが、Greptile の cross-repo 文脈・embedding 検索が初回レビューで価値を出すリポ。PR 数が月 5〜10 件程度で、50 件/seat 枠を圧迫しない
- Tier 3 にする条件: 商用 IaC scanner（Wiz / Prisma / Snyk）が稼働済みで Greptile rule との重複が大きい / PR 数が極小・閉じたツールリポ / Claude Code の Phase 2 で一貫性チェックが十分なリポ

Tier 3 の運用:
- `.greptile/config.json` の削除では初回レビューを止められない（GitHub App がインストールされていれば既定挙動で走る）。GitHub App をリポから uninstall するのが正規手段
- 切り替え順は: (1) GitHub App から該当リポを外す → (2) リポの `.greptile/` 配下を削除 → (3) `CLAUDE.md` 等の Greptile 言及を整理。順序を逆にすると、設定ファイルが残ったまま App が走る or App が残ったまま設定削除で混乱する
- setup-ci-review skill では step 2 のコンポーネント選択で Greptile を deselect することで Tier 3 構成として bootstrap できる（既存リポを Tier 3 化する場合は `update-existing.sh` ではなく手動削除が必要）

Tier 見直しの周期: 四半期。`harness-audit` skill の運用サイクルに合わせて、PR 数推移と seat 枠使用量を見て判定する。

## IaC観点カタログ

SKILL.md の手順4で `{{REVIEW_CRITERIA}}` に展開する内容。

```
## レビュー観点（IaC固有）

### 基本観点

- IAM: 最小権限の原則、roles/editor禁止、roles/ownerは明示管理のみ、allUsers/allAuthenticatedUsers禁止
- WIF: attribute_conditionによるリポジトリ制限を必ず設定
- State: import/moved/removedブロックの宣言的記述
- API: disable_on_destroy = true の設定
- Project: lifecycle.prevent_destroy = true の設定
- 命名: Terraform識別子はsnake_case、リソース名はハイフン区切り
- IAM管理: iam_member（加算的）を使用、iam_binding/iam_policyは禁止

### IAM変更の判断基準

| 変更内容 | 重要度 | 判断理由 |
|---------|--------|---------|
| roles/viewer, roles/reader 系の付与 | P2 | 読み取りのみ、影響限定的 |
| roles/editor, roles/storage.objectAdmin 系の付与 | P1 | 書き込み権限、意図を確認 |
| roles/owner の付与 | P0 | 最高権限、原則禁止 |
| allUsers / allAuthenticatedUsers への付与 | P0 | パブリックアクセス、セキュリティリスク大 |
| attribute_condition なしの WIF 設定 | P0 | 任意リポジトリからのなりすまし可能 |
| サービスアカウントキーの新規作成 | P1 | 鍵漏洩リスク、WIF推奨 |
| iam_binding / iam_policy の使用 | P1 | 既存権限の上書き破壊リスク |

### 破壊的変更の分類

| 変更パターン | 重要度 | 判断理由 |
|------------|--------|---------|
| リソースの force new（再作成トリガー）| P0 | データ損失・サービス停止リスク |
| force_destroy = true の追加 | P0 | バケット・DBの意図せぬ削除を許容する変更 |
| deletion_protection の解除 | P0 | リソース削除ロック解除 |
| VPC / Firewall rule の削除 | P1 | ネットワーク疎通に影響 |
| GKE クラスタ設定の変更（node pool 含む） | P1 | ローリング再起動・縮退リスク |
| moved ブロックなしのリソース名変更 | P1 | Terraform が削除→再作成と判断する |
| タグ・ラベルのみの変更 | P3 | 実リソースへの影響なし |

### コスト影響の判断基準

| 変更内容 | 重要度 | 判断理由 |
|---------|--------|---------|
| 高コストリソースの新規作成（Spanner, GKE node pool, BigQuery reserved slot 等） | P1 | 月次コストへの大きな影響 |
| 既存リソースのスペック2倍以上のスケールアップ | P2 | コストレビュー推奨、意図を確認 |
| 通常リソースの追加・変更 | P3 | 影響軽微 |

### 監視・メッセージング・CDN の判断基準

| 変更内容 | 重要度 | 区分 | 判断理由 |
|---------|--------|------|---------|
| Datadog Monitor の削除・無効化 | P1 | 文脈依存 | 本番監視対象前提。テスト用Monitorなら影響なし |
| Pub/Sub subscription の delivery設定変更（ack_deadline / dead_letter_policy）| P1 | 文脈依存 | 本番Pub/Sub前提。未使用 subscription なら影響なし |
| Fastly / Cloudflare CDN のキャッシュルール変更 | P1 | 文脈依存 | 本番CDN前提。未リリース環境なら影響限定的 |
| Wiz / PagerDuty 設定の変更 | P2 | 絶対 | セキュリティ検知・オンコール体制に影響、意図を確認 |
| アラート閾値の緩和 | P1 | 文脈依存 | 本番アラート前提。dev用なら影響なし |
```

## Checkov設定方針

- `framework: terraform` を明示する
- `soft_fail: false` で P0 相当をブロック
- `baseline` ファイル: 新規導入直後は既存違反を凍結し、新規混入のみブロック
  - 初回: `checkov -d . --framework terraform --create-baseline`
  - その後: baseline ファイルをコミットし `baseline:` 行を有効化
- `skip_check`: 誤検知の多いルールを明示除外。コメントで理由を残す

## Claude Code workflow の成熟度レベル

setup-ci-review が生成する `claude-review.yml` は WinTicket/server で実運用されている構成をベースにしている。以下の機能が組み込まれている。

### コア機能（常に有効）

- `pull_request` トリガー（opened / synchronize / reopened / ready_for_review）
- `issue_comment` トリガー: `@claude` を含むコメントで手動再レビュー（MEMBER/OWNER/COLLABORATOR 限定）
- `gh pr checkout` step: issue_comment 時にPR branchに切り替え
- force-push 検出: `git merge-base --is-ancestor` で判定、フル/増分を切り替え
- `allowed_bots`: dependabot/renovate の bot PR もレビュー対象
- `display_report: true` + Workflow Summary
- インラインコメント投稿: `mcp__github_inline_comment__create_inline_comment`
- 履歴蓄積型トップレベルコメント: `<!-- claude-code-review -->` マーカー付きコメントに追記
- PR review 判定: P0/P1 ありで `--request-changes`、無ければ `--approve`
- WebSearch / WebFetch（pkg.go.dev / github.com / raw.githubusercontent.com）: 外部ドキュメント参照

### モデル選択

デフォルトは `--model claude-opus-4-5`（深い設計レビュー）。
軽量運用したい場合は `--model` 行を削除して action のデフォルト（Sonnet）に委ねる。

新モデル（`claude-opus-4-7` / `claude-sonnet-4-6` 等）を指定する場合は事前に動作確認すること。action / SDK 側の thinking API 互換性により `"thinking.type.enabled" is not supported for this model` で 400 エラーになるケースが過去にあった。

### action バージョン固定理由

`1c8b699d43e9bfed42b48ef15da85d89bab70960`（v1.0.94）を使用。

- `mcp__github_inline_comment__create_inline_comment` は v1.0.94 / v1.0.101 いずれも引き続き利用可能（過去の「v1.0.101 で削除」という記述は誤り）
- v1.0.94 で PR branch 上の `.claude/` と `.mcp.json` を base branch から自動 restore する防御が入った（attacker-controlled な指示ファイルを Claude に読ませない）。SKILL.md はこの挙動前提で書く（`.claude/skills/claude-code-review/SKILL.md` は base branch 版が読まれる）
- `id-token: write` 必須だが ANTHROPIC_API_KEY 直接認証と併用可能
- サプライチェーン対策として SHA pin（タグ参照禁止）

### allowedTools の設計思想

```
mcp__github_inline_comment__create_inline_comment  # インラインコメント
Bash(gh pr comment:*)                              # 新規トップレベルコメント
Bash(gh pr diff:*)                                 # 差分取得
Bash(gh pr view:*)                                 # PR情報取得
Bash(gh pr review:*)                               # 最終判定（--approve / --request-changes）
Bash(gh api repos/*/issues/*/comments:*)           # 既存コメント一覧取得
Bash(gh api --method PATCH repos/*/issues/comments/*:*)  # 既存コメント追記
Bash(find|cat|grep|ls|git diff|git log:*)          # コードベース探索
WebSearch                                          # 外部検索
WebFetch(domain:pkg.go.dev|github.com|raw.githubusercontent.com)  # ドキュメント取得
```

`gh pr review:*` をワイルドカード許可しているのは、SKILL.md 側で `--approve` / `--request-changes` を切り替える設計のため。`--approve` を AI に出させたくない運用に切り替える場合は、SKILL.md の「PR レビュー判定」セクションを `--comment` 系に書き換えると同時に、ここの allowedTools も `Bash(gh pr review --comment:*)` などに絞り込むこと。

## デバッグのヒント

Claude が「何も投稿せずに完了」する場合のチェックリスト:

1. action バージョンが v1.0.94 か（SHA `1c8b699d...`）
2. `--allowedTools` に `mcp__github_inline_comment__create_inline_comment` が含まれているか
3. `permissions.pull-requests: write` と `permissions.id-token: write` があるか
4. prompt に「投稿ルール（必須）」セクションがあり、`gh pr comment` / `gh pr review` の具体的なコマンドが書かれているか
5. `--max-turns` が 50 以上あるか（30 以下だと SKILL.md が長いケースで投稿前に turn 切れする）
6. `issue_comment` トリガーの場合、`gh pr checkout` step が実行されているか（default branch のままだと diff が空になる）

Workflow が `Workflow validation failed` で失敗する場合:

- v1.0.94 のセキュリティ機能で PR branch と main の workflow 差分をチェックしている
- workflow 変更 PR 自身では動作しない（マージ後の別 PR で動作確認）
