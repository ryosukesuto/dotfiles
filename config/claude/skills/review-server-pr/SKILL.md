---
name: review-server-pr
description: WinTicket/server リポジトリ専用のPRレビュー。クリーンアーキテクチャ、コーディング規約、クロスリポジトリ整合性を検証する。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
  - mcp__ragent__hybrid_search
---

# /review-server-pr - server リポジトリ専用PRレビュー

WinTicket/server リポジトリのPRを、プロジェクト固有のルールとクロスリポジトリ整合性の観点でレビューする。

## 基本方針

- レビューコメントは日本語で記述
- 指摘には優先度ラベルを付ける:
  - `[P0]` 本番障害・データ不整合に直結。マージ前に必ず修正
  - `[P1]` デプロイ失敗・性能劣化・セキュリティリスク。強く修正を推奨
  - `[P2]` コード品質・保守性の改善。対応推奨
  - `[P3]` 軽微な改善提案。対応任意
- P0/P1 がなければその旨を明記し、P2 以下のみ報告
- P2/P3 は合計5件以内に絞り、影響度の高いものを優先
- 自信がない指摘はしない。推測ベースの false positive はレビューの信頼性を損なう
- 良い変更にはポジティブフィードバックを添える

### レビュー対象外

CI / linter の責務のため指摘しない:

- `goimports` / `gofmt` で検出できるフォーマット
- `custom-gcl` で検出される lint 違反（loguppercase, errorprefix 等）
- `buf lint` で検出される proto 違反
- `*_gen.go`, `*.pb.go`, `mock/` 配下の自動生成ファイルの内容（存在確認・インターフェース整合性チェックのみ）

## 実行手順

### 0. ルール読み込み

レビュー精度を上げるため、以下のリファレンスを読み込む:

- `${CLAUDE_SKILL_DIR}/server-rules.md` — serverリポジトリ固有ルール
- `${CLAUDE_SKILL_DIR}/cross-repo-rules.md` — server-config/ops連動ルール
- `${CLAUDE_SKILL_DIR}/context.local.md` — 環境固有の機密情報（存在する場合のみ）

### 1. PR情報の取得

```bash
gh pr view --comments
gh pr diff
gh pr checks
```

### 2. 既存レビューコメントの確認

```bash
gh api "repos/{owner}/{repo}/pulls/$(gh pr view --json number -q .number)/comments" \
  --jq '.[] | "[\(.user.login)] \(.path):\(.original_line // .line) - \(.body[0:200])"'
```

- 指摘済みの問題を重複して報告しない
- 未解決コメントがあれば自分の判断を添える
- 誤った指摘があれば理由を添えて訂正を提案

### 3. 変更スコープの特定

PRタイトルの `{区分}({package name}):` からマイクロサービスを特定し、レビュー観点を絞る。

| パッケージ | 重点観点 |
|-----------|---------|
| gateway, admin | OpenAPIアノテーション、レスポンス変換、ビジネスロジック混入 |
| broker | 決済ロジック、Spannerトランザクション、金額計算 |
| keirin, autorace, keiba | ドメインロジック、外部システム連携 |
| user | 認証・認可、個人情報取り扱い |
| messenger | 通知、Pub/Sub、冪等性 |
| proto | 破壊的変更、フィールド番号 |
| `*` | 全サービス影響、共通パッケージ変更 |

### 4. Codex分析の実施（推奨）

tmux/cmux 環境が利用可能な場合、Codexに独立したレビューを依頼する。

```bash
PANE_MGR=~/.claude/skills/codex-review/scripts/pane-manager.sh

$PANE_MGR ensure
$PANE_MGR send "gh pr diffをレビューしてください。P0-P3の優先度で問題を分類し、各指摘は [PX] file:line - 問題の要約 の形式で報告してください。特にクリーンアーキテクチャの依存方向、Spannerトランザクション、エラーハンドリングに注目してください。"
$PANE_MGR wait_response 180
$PANE_MGR capture 300
```

`$PANE_MGR ensure` が失敗した場合のみ `codex exec` にフォールバック。
Codex の技術的主張は、該当コードを実際に読んで検証してからレビューに含める。

### 5. クロスリポジトリ影響の確認

以下に該当する変更がある場合、`cross-repo-rules.md` のチェックリストを適用:

- コマンドライン引数（Cobra flags）の追加・変更・削除
- gRPC サービス定義の変更
- Spanner テーブル / カラムの前提変更
- 環境変数・Secret の参照追加

### 6. 統合レビューの作成

Codex分析・自身の評価・既存コメントを統合し、`${CLAUDE_SKILL_DIR}/reference.md` の出力フォーマットに従う。

## 優先度の判断基準

| 優先度 | 内容 | server 固有の例 |
|--------|------|----------------|
| P0 | マージ前に必須 | 決済金額の計算ミス、認証バイパス、Spanner デッドロック誘発、proto 破壊的変更 |
| P1 | 次のサイクルで対応 | N+1クエリ、errgroup 未使用の並行処理、エラーラップ漏れ、クロスリポ整合性 |
| P2 | いずれ修正 | 命名規約違反（`To` 接頭語等）、capacity 未指定の slice、@gen 未活用 |
| P3 | 余裕があれば | ログメッセージ改善、コメント追加 |

## Reader Testing（300行以上のPR、任意）

300行以上のPRでは `${CLAUDE_SKILL_DIR}/reference.md` のReader Testingを参照。

## Gotchas

(運用しながら追記)
