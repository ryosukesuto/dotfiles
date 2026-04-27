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

### P3. 3回ルールと双方向ライフサイクル管理

カテゴリ: F. ガードレール
効果: 同じ違反を繰り返さない仕組みを段階的に構築しつつ、ハーネスがラチェット化（単調増加）するのを防ぐ

エスカレーション階層（上げる方向）:

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

降格・撤去階層（下げる方向）:

エスカレーションだけでは強制力が単調増加し、ハーネスが膨張する。追加と対称的に「下げる条件」を必ず持つ。

```
N四半期ヒットゼロ → 1段階下げる（CI → hook、hook → linter、linter → docs）
2N四半期ヒットゼロ → 撤去候補（設計側で吸収済み or モデル進化で不要）
摩擦コスト > 防止効果 → 即時降格 or 撤去（誤検知率・ローカル待機時間で判断）
```

注意:
- 「3回」「N四半期」の閾値そのものは絶対視しない。同一週に集中した3回と、半年に散らばった独立3回は重みが違う
- 数えやすい違反だけが強化されるバイアスに注意。設計の曖昧さやレビュー品質など定量化しにくい問題は別途扱う
- 固定順序（docs → linter → hook → CI）に縛られない。最安の有効点に置く。CIにしか置くべきでないルールもある

メタ情報テンプレート:

ルールを追加する際、以下6項目を必ず併記する。これがないルールは棚卸し対象になる。

```yaml
# 例: import/no-cycle を CI で必須化
rule: import/no-cycle を CI 必須化
reason: 2026-04 に循環依存が3回再発（commit a1b2c3, d4e5f6, g7h8i9）
added: 2026-04-27
expires: 2026-07-31
owner: ryosukesuto
downgrade_if: 次の四半期で再発 0 件なら hook へ降格
```

各項目の意味:

| 項目 | 説明 |
|---|---|
| `rule` | 何を強制しているか（1行） |
| `reason` | なぜ必要か。再発した失敗類型・関連 commit / PR / incident |
| `added` | 追加日（YYYY-MM-DD） |
| `expires` | 見直し期限。**自動削除トリガーではなく、レビュー必須フラグ** |
| `owner` | 期限到来時の判断責任者 |
| `downgrade_if` | どの観測で1段階下げるか。事前に決めておく |

置き場所別の運用:

| ルールの置き場所 | メタ情報の持ち方 |
|---|---|
| `CLAUDE.md` / `rules/` | 該当節の冒頭にコメント or YAML front matter |
| linter 設定（`.golangci.yml` 等） | 該当ルールの直前にコメント |
| CI（`.github/workflows/`） | YAML コメント or 別途 `docs/harness-rules.md` で台帳化 |
| hooks（`pre-commit` / `lefthook.yml`） | スクリプト冒頭コメント |

リポジトリ規模が大きい場合は `docs/harness-rules.md` で一元台帳管理する方が棚卸ししやすい。

棚卸しフロー（四半期ごと、または harness-audit 実行時）:

```
1. expires <= today のルールを一覧化
2. 各ルールについて、追加以降の再発・誤検知・摩擦を確認
3. 維持 / 降格 / 撤去 の3択で判定
   - 維持: 期限中に再発した、または外すと事故コストが高い → 新しい expires と reason を更新
   - 降格: 再発は止まったが不安が残る → CI → hook / hook → lint に下げる
   - 撤去: 再発 0 + 摩擦の方が大きい or 設計側で吸収済み → 削除
4. 「期限切れ放置」が最大のアンチパターン。判断を保留する場合も、新しい expires を必ず設定する
```

リポジトリ tier 別の運用強度:

全リポジトリに同じ強度を適用しない。tier で監査圧を変える。

| tier | 対象 | ルール追加 / 棚卸し頻度 |
|---|---|---|
| `full` | プロダクト・本番運用リポ | 監査四半期ごと、ルール追加時メタ情報必須、降格条件必須 |
| `light` | 内製ツール・補助的なリポ | 監査半期ごと、メタ情報は推奨レベル |
| `scratch` | 実験・個人スクラッチ | 監査なし、ハーネスは最小（main 保護のみ等） |

---

### P4. ループ検出と自動中断

カテゴリ: F. ガードレール
効果: エージェントが同じエラーで無限ループに陥るのを検出し、アプローチの切替を促す

検出の基本方針:

ドゥームループは「変更の有無」ではなく「同一エラーの再発」で判定する。以下のシグナルを組み合わせる。

- 同一コマンド（lint / test / build）が同一エラーメッセージで N 回連続失敗
- 同一ファイルのハッシュが M 回連続で「修正 → 失敗 → 戻す」を繰り返している
- PostToolUse Hook のリトライ回数が閾値（例: 3）を超える
- 振り子（oscillation）パターン: 同一箇所で `A → B → A → B` と反対の修正を往復する。レビュアーからの矛盾指摘に反応して前回の修正を打ち消す挙動が典型。同一ハンクで直前の commit と逆向きの差分が2往復以上で判定する

振り子パターンへの対処: 一度トリアージで採用した directive は後続 iteration で固定化する。レビュー→修正ループを持つ仕組み（PR自動レビュー、`fix-review-comments` 等）では、採用した判定を JSON / commit trailer 等に記録し、次の iteration で再交渉させない。

PostToolUse Hook での検出スクリプト例（擬似コード）:

```bash
#!/bin/bash
# .claude/hooks/detect-loop.sh
STATE_FILE=".claude/.loop-state"
ERROR_SIG=$(tail -n 5 "$CLAUDE_LAST_COMMAND_LOG" 2>/dev/null | sha1sum | cut -d' ' -f1)
LAST_SIG=$(cut -d: -f1 "$STATE_FILE" 2>/dev/null)
COUNT=$(cut -d: -f2 "$STATE_FILE" 2>/dev/null || echo 0)

if [ "$ERROR_SIG" = "$LAST_SIG" ]; then
  COUNT=$((COUNT + 1))
  if [ "$COUNT" -ge 3 ]; then
    echo "LOOP DETECTED: same error repeated $COUNT times. Change approach." >&2
    exit 2  # ブロック
  fi
else
  COUNT=1
fi
echo "$ERROR_SIG:$COUNT" > "$STATE_FILE"
```

注意:
- Stop Hook で「git diff が空なら警告」を出す簡易版は、レビュー・調査・read-only タスクで誤警告するため本番運用しない
- 誤検知対策として、success 時に `$STATE_FILE` をリセットする PostToolUse も合わせて設定する
- retry 上限は言語・プロジェクト特性で調整（Go のテスト flake が多いなら 5、TS の type エラーなら 3 など）

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

TypeScript / Node.js 向けは `tsc --noEmit` + `biome check` + `vitest run` の3段を CI に移植する。

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

### P10. PR 2-Approve ハーネス（人間 + AI）※上級者向けオプション

カテゴリ: F. ガードレール（副次的に B. フィードバックループにも寄与）
位置付け: デフォルト推奨ではない。既に人間2名レビューが機能しているチームが運用コストを下げたい場合の段階的導入オプション
効果: PR マージのゲーティングを人間1名 + AI1名で構成し、AI が本番リスクの検出を担う。人間レビュアーの負荷を下げつつ、誤マージを防ぐ

導入条件（全て満たすまで導入しない）:
- Linter / 型チェック / テストが CI で強制されている（B ≥ 4）
- Secret scanning と main 保護が動いている（F ≥ 4）
- 評価者の独立性が確保できる（書くセッションとレビューするセッションが分離）
- Approve 判定の誤判定時にロールバックできる手段が明文化されている

計測期間:
- 導入前に 2-4 週間は「AI が Request Changes 提案のみ行い、Approve は必ず人間」のシャドーモードで運用する
- 誤 Approve（= AI が Approve したが本番で問題が発覚した PR）がゼロであることを確認してから Approve 権限を委譲する
- 誤判定率が計測できないチームは導入しない

ロールバック手順:
- AI の Approve 権限を剥奪し、人間2名レビューに戻す（GitHub 設定・CODEOWNERS 変更で数分）
- 過去の AI Approve PR を一覧化し、リスクレビューを再実施
- 原因分析（プロンプト / 補正ルール / コンテキスト不足）を行い、修正後に再試行

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

### P11. Secret Scan による認証情報漏洩検知

カテゴリ: F. ガードレール
効果: `.env` / API key / token の誤コミットを PR ゲートで検出し、push protection を補完する

デフォルト推奨: TruffleHog workflow（OSS / 無料・private repo でも利用可）

```yaml
# .github/workflows/secret-scan.yml
name: Secret Scan

on:
  push:
    branches:
      - main
  pull_request:
    types: [opened, synchronize, reopened]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  trufflehog:
    name: TruffleHog
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA> # v6
        with:
          fetch-depth: 0

      - uses: trufflesecurity/trufflehog@<SHA> # v3.95.2
        with:
          extra_args: --results=verified,unknown
```

検出フィルタの意味:

- `verified`: 検証器が有効性を確認した認証情報のみ。false positive ほぼゼロ
- `unknown`: 検証器が存在しない detector でヒットしたもの。様子見
- `unverified`（デフォルトだが除外推奨）: 検証失敗したもの。失効済み key で大量ヒットしノイズ化する

ツール選定の注意:

- `gitleaks/gitleaks-action@v2` は GitHub Action が **private org で有料**（2023年以降）。public repo / 個人利用は無料だが、業務用 private org では課金対象
- `gitleaks` CLI 本体は MIT OSS で無料。workflow で `go install` or `curl` install して直接叩けば無料で使えるが、TruffleHog の方が検証済み detector を持つため精度が高い
- GitHub Advanced Security 契約がある org では Secret Scanning + push protection で代替可能（追加コストゼロ、push 時点でブロック）

pre-commit 版（任意）:

```bash
# .husky/pre-commit や lefthook で
# trufflehog git file://. --since-commit HEAD --only-verified --fail
```

pre-commit に入れる場合は verified のみに絞らないと履歴スキャンで遅延が出る。

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
| 振り子修正 | レビュー指摘ごとに前回修正を打ち消し `A→B→A→B` を往復 | directive を iteration 間で固定化（P4） |
| バンドエイド修正 | 症状だけ抑えて根本原因を残す（try/except で握り潰し、型エラーを `any` で回避、テストをskipで通す等） | 修正後に別 session / 別エージェントで「根本原因に対処したか」を独立検証。評価者の独立性（F カテゴリ）と組で運用 |
