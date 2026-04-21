## パターンカタログ

監査で課題が検出された場合の改善テンプレート集。各パターンには「何を」「なぜ」「どう実装するか」を含む。

---

### P1. PostToolUse Hookによる即時フィードバック

カテゴリ: B. フィードバックループ
効果: エージェントがファイル保存するたびに自動フォーマット+リンターが走り、コミット前に問題を解消

settings.json への追加例:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "# 言語に合わせて選択:\n# TypeScript: npx biome check --write $CLAUDE_FILE_PATHS\n# Python: ruff check --fix $CLAUDE_FILE_PATHS && ruff format $CLAUDE_FILE_PATHS\n# Go: gofmt -w $CLAUDE_FILE_PATHS"
          }
        ]
      }
    ]
  }
}
```

注意: `$CLAUDE_FILE_PATHS` は変更されたファイルのパスに展開される。

---

### P2. 段階的開示によるコンテキスト設計

カテゴリ: A. コンテキスト設計
効果: CLAUDE.mdの肥大化を防ぎ、必要な情報を必要なときだけロードする

構造例:

```
CLAUDE.md                    ← 50-100行。ビルド/テスト/デプロイコマンド + ポインタ
.claude/rules/
  architecture.md            ← レイヤー構造・依存方向
  testing.md                 ← テスト方針・命名規則
  security.md                ← セキュリティ制約
docs/
  adr/                       ← Architecture Decision Records
  coding-guidelines.md       ← コーディング規約の詳細
```

CLAUDE.mdに書くもの:
- ビルド・テスト・デプロイのコマンド（コピペで動く形式）
- ディレクトリ構造の概要（5-10行）
- 非自明なGotchas（3-5項目）
- 詳細ドキュメントへのポインタ

CLAUDE.mdに書かないもの:
- コードを読めばわかる情報
- 長大なコーディング規約（rules/ に分離）
- 一時的な情報（issueリスト、進行中タスク）

---

### P3. 3回ルールによる段階的強制力エスカレーション

カテゴリ: F. ガードレール
効果: 同じ違反を繰り返さない仕組みを段階的に構築する

エスカレーション階層:

```
1回目: ドキュメントに記載（CLAUDE.md / rules/）
  → エージェントが参照すれば守る程度

2回目: AI検証を追加（カスタムリンタールール）
  → エラーメッセージに修正指示を含める

3回目: ツール検証を追加（Hook / pre-commit）
  → 自動で検出・修正する

4回目以上: 構造テスト（ArchUnit等）/ CIゲート
  → マージ自体をブロックする
```

実例: importの循環依存

```
1回目 → CLAUDE.mdに「循環依存禁止」と記載
2回目 → ESLintの import/no-cycle ルールを追加
3回目 → PostToolUse Hookで自動チェック
4回目 → CIでブロック
```

---

### P4. ループ検出と自動中断

カテゴリ: F. ガードレール
効果: エージェントが同じエラーで無限ループに陥るのを防止

Stop Hookでの検出例:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "# 直近のgit diffが空なら「変更なしで完了宣言」を検出\nif [ -z \"$(git diff HEAD)\" ]; then echo 'WARNING: No changes detected. Review if the task is actually complete.' > /dev/stderr; fi"
          }
        ]
      }
    ]
  }
}
```

CLAUDE.mdへの追記例:

```markdown
## エラー対応ルール
- 同じエラーが3回続いたら、アプローチを変える。同じ修正の繰り返しは禁止
- テストが通らない場合: 1) エラーメッセージを読む 2) 原因を特定する 3) 異なるアプローチを試す
```

---

### P5. GitHub Actions CI ワークフロー（Go）

カテゴリ: B. フィードバックループ
効果: PR 時に go vet + go test + golangci-lint を自動実行する

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: ["main"]
  pull_request:

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA> # v4
      - uses: actions/setup-go@<SHA> # v5
        with:
          go-version-file: go.mod
      - run: go vet ./...
      - run: go test ./...

  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA> # v4
      - uses: actions/setup-go@<SHA> # v5
        with:
          go-version-file: go.mod
      - name: Install golangci-lint
        run: go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest

      - name: golangci-lint
        run: golangci-lint run ./...
```

SHA の取得方法（テンプレートの `<SHA>` を実際の値に置き換える）:

```bash
gh api repos/actions/checkout/git/refs/tags/v4 --jq '.object.sha'
gh api repos/actions/setup-go/git/refs/tags/v5 --jq '.object.sha'
```

注意:
- WinTicket を含む多くのリポジトリでは、全 Action をフル長 SHA にピン留めすることが必須。`@v5` のようなタグ参照は CI が即座に失敗するため使用しない
- `golangci-lint-action` はプリビルドバイナリを使うため、プロジェクトの Go バージョンより古い Go でビルドされていると "Go language version used to build golangci-lint is lower than targeted" で失敗する。`go install` でプロジェクトと同じ Go バージョンからビルドすることで回避できる

Shell/bash リポジトリ向けテンプレ:

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: ["main"]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA> # v4
      - name: Install shellcheck / shfmt
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck
          curl -fsSL -o /usr/local/bin/shfmt https://github.com/mvdan/sh/releases/latest/download/shfmt_v3.8.0_linux_amd64
          chmod +x /usr/local/bin/shfmt
      - run: shfmt -d -i 4 $(git ls-files '*.sh' 'bin/*' 'hooks/*' | xargs -I{} sh -c 'head -1 "{}" | grep -q "^#!.*sh" && echo "{}"')
      - run: shellcheck $(git ls-files '*.sh')
```

TypeScript / Node.js 向けテンプレは P2 の構造（`tsc --noEmit` + `biome check` + `vitest run`）を CI に移植する。

---

### P6. カスタムリンターによる制約の自動化

カテゴリ: C. アーキテクチャ制約
効果: リンターのエラーメッセージが修正指示を兼ねるため、エージェントが自己修正できる

推奨するエラーメッセージ形式（OpenAIパターン）:

```
ERROR: [何が間違っているか]
  [ファイル:行番号]
  WHY: [ルール理由、ADR リンク]
  FIX: [具体的な修正手順、コード例]
```

エラー自体に「何が問題か」「なぜ問題か」「どう直すか」を含めることで、エージェントが1サイクルで自己修正できる。PR レビュー AI の Request Changes コメントにも同形式を適用できる。

4つのカテゴリで設計:

1. Grep-ability（検索容易性）
   - 一貫した命名規則の強制
   - マジックナンバーの禁止

2. Glob-ability（ファイル配置の予測可能性）
   - ファイル配置規則の強制（コンポーネントは components/ 以下等）
   - テストファイルの命名パターン

3. アーキテクチャ境界
   - レイヤー間の不正なimportの禁止
   - パッケージ間の依存方向の強制

4. セキュリティ
   - ハードコードされた認証情報の検出
   - 危険なAPIの使用警告

推奨リンター:
- TypeScript: Oxlint（高速） + Biome（フォーマット兼用）
- Python: Ruff（高速、Flake8 + isort + Black の統合）
- Go: golangci-lint v2（多数のリンターを統合）

golangci-lint v2 の設定ファイル形式（`.golangci.yml`）:

```yaml
version: "2"  # v2 では必須。ないと "unsupported version" エラーで即失敗

linters:
  enable:
    - errcheck
    - govet
    - staticcheck

formatters:
  enable:
    - gofmt  # v2 では linters ではなく formatters セクションに移動

linters-settings:
  errcheck:
    check-type-assertions: true

issues:
  exclude-rules:
    - path: "_test\\.go"
      linters:
        - errcheck
```

---

### P7. Skill化による反復ワークフローの標準化

カテゴリ: E. 計画と実行の分離
効果: 繰り返しのワークフローを1コマンドに集約し、品質のばらつきを排除

Skill化の判断基準:

```
同じ手順を2回以上実行した → Skill化を検討
3回以上実行した → Skill化すべき
外部ツールとの連携が必要 → Skill化（スクリプト含む）
チーム共有したいフロー → プロジェクトSkill (.claude/skills/)
個人的なフロー → ユーザーSkill (~/.claude/skills/)
```

---

### P8. Subagentによるコンテキスト分離

カテゴリ: E. 計画と実行の分離
効果: 中間ノイズが親スレッドに蓄積するのを防止し、コンテキストの品質を保つ

使い分け:

```
Subagentを使うべき場面:
- 大量のファイル検索・分析（結果の要約だけ親に返す）
- 独立したタスクの並行実行
- 異なる専門性が必要なレビュー（品質・パフォーマンス・セキュリティ）

Subagentを使わない場面:
- 単純な1ファイルの修正
- 依存関係のある順次作業
- コンテキスト共有が必要な議論
```

---

### P9. mainブランチ保護

カテゴリ: F. ガードレール
効果: エージェントの意図しないmainコミットを物理的にブロック

pre-commit hookの例:

```bash
#!/bin/bash
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  # opt-out設定の確認
  if [ "$(git config --bool wt.allowDirectCommit 2>/dev/null)" = "true" ]; then
    exit 0
  fi
  echo "ERROR: Direct commits to $branch are not allowed."
  echo "Create a worktree: git-wt add feature/xxx"
  exit 1
fi
```

---

### P10. PR 2-Approve ハーネス（人間 + AI）

カテゴリ: B. フィードバックループ / F. ガードレール
効果: PR マージのゲーティングを人間1名 + AI1名で構成し、AI が本番リスクの検出を担う。人間レビュアーの負荷を下げつつ、誤マージを防ぐ

構成:

| 層 | 担当 | 対象 |
|----|------|------|
| AIレビュー（Claude Code） | P0/P1 の検出と Approve / Request Changes 判定 | 本番リスク・セキュリティ・権限・コスト |
| 補助AI（Greptile 等） | 一般的なバグ・命名・typo | blocking せずコメントのみ |
| Linter / ハーネス | P2/P3 の自動検出・修正 | フォーマット・未使用変数・スタイル |
| 人間レビュー | 設計判断・事業観点・AI の誤判定のガード | 全体 |

判定ロジック:

- P0/P1 が1件以上ある → `gh pr review --request-changes`
- P0/P1 がなく P2/P3 のみ or 指摘なし → `gh pr review --approve`

重要度の定義例:

- P0: 本番の可用性・セキュリティに直結。絶対に修正が必要（認証バイパス、個人情報漏洩、データ消失）
- P1: 本番で問題を起こす可能性（破壊的変更、監視欠落、過剰な権限付与）
- P2: 品質・保守性の改善が望ましい（Approveしつつコメントに残す）
- P3: 軽微な提案（任意対応）

コンテキスト補正:

PR 説明に「未リリース」「dev 専用」「意図と緩和策」が明示されている場合、P0 → P1、P1 → P2 のように1段下げる。ただし絶対 P0（セキュリティ・権限昇格）は補正不可。PR テンプレートに以下を含めると AI が補正しやすい。

```markdown
## 影響範囲
- 対象環境: [ dev / stg / prd / 未リリース ]
- 本番ユーザー影響: [ なし / 限定的 / あり ]

## 意図と緩和策（P0/P1 に該当する変更がある場合のみ）
- 意図: 
- 緩和策: 
- ロールバック手順: 
```

運用上の注意:

- 評価者の独立性: コードを書く Claude Code session とレビューする Claude Code session を分離する（自己評価による甘い判定を防ぐ）
- Request Changes コメントは P6 の ERROR/WHY/FIX 形式を使う
- 精度計測: 誤 Approve ゼロが必須条件。AI 生成 PR と人間生成 PR で Approve 率に差が出ないか観察する

---

## アンチパターン集

監査で検出すべき問題パターン。

| アンチパターン | 症状 | 対処 |
|--------------|------|------|
| CLAUDE.md肥大化 | 300行超の単一ファイル | 段階的開示（P2）に分割 |
| プロンプトだけの制約 | ルールが守られない | リンター/Hook で強制（P3） |
| Tool Bloat | MCPサーバーの無差別追加 | 未使用ツールを棚卸し、最小限に |
| 全社ナレッジ一括投入 | コンテキストが「ゴミ埋立地」化 | 段階的開示、必要時のみロード |
| 自己評価への依存 | エージェントが品質を正しく判断できない | 独立した検証手段（テスト、リンター、Codex） |
| ドキュメント腐敗 | 古いルールに従って誤った実装 | 定期スキャン + 鮮度管理（D） |
| 過剰なハーネス | Hookが多すぎてレスポンスが低下 | Build to Delete: モデル進化で不要になった制約を除去 |
| 事前最適化 | 実際のエラーなしにハーネスを過剰設計 | エージェントが失敗してから対処する |
| 完全自動化信仰 | 人間の監督なしに全委任 | ハイレバレッジな意思決定ポイントに人間を配置 |
| ドゥームループ | 同じ失敗パターンの無限繰り返し | ループ検出（P4） + 3回ルール（P3） |
