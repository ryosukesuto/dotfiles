---
name: harness-audit
description: リポジトリのハーネス構成を監査し、AIコーディングの堅牢性を改善する。「ハーネス監査」「harness audit」「ハーネスチェック」「リポジトリ監査」「AI開発の品質改善」等で起動。
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Agent
user-invocable: true
---

# /harness-audit - リポジトリのハーネス構成監査

リポジトリがAIコーディングエージェントと協働するための環境（ハーネス）を6カテゴリで監査し、改善提案を出す。

ハーネスとは、AIエージェントの周囲に構築する制約・ツール・ドキュメント・フィードバックループの総体のこと。モデルの性能よりハーネスの品質が成果を左右する。

## 実行手順

### 1. 現状収集

#### 実行モードの判定

以下のいずれかに該当する場合は **Mode B（大規模リポ向け Phase 1 並列化）** を使う。それ以外は **Mode A（標準）** で main セッション内で完結させる。

判定シグナル（いずれか1つで Mode B を推奨）:

```bash
# Mode B 推奨条件のいずれかで true になる
[ "$(git ls-files 2>/dev/null | wc -l)" -gt 3000 ] || \
[ "$(find . -name '*.tf' 2>/dev/null | wc -l)" -gt 100 ] || \
[ "$(ls .github/workflows/ 2>/dev/null | wc -l)" -gt 8 ]
```

ユーザーが明示的に「巨大リポ」「ops」「monorepo」「並列で」のように指定した場合も Mode B。判定が微妙なら Mode A から始め、Phase 1 で context window が逼迫してきたら Mode B に切り替える。

#### Mode A: 標準モード（既定）

main セッションで以下を並行で調査する。ファイルが存在しない項目はスキップし、「未構成」として記録する。Claude 固有パスは例示であり、他エージェント（Cursor / Cline / Codex / Aider など）の等価成果物も同等に扱う。

```
# コンテキスト設計 (A)
agent-docs: CLAUDE.md, AGENTS.md, .cursor/rules/, .cursorrules, .clinerules
ルール集: .claude/rules/, docs/, docs/adr/
スキル/プロンプト: .claude/skills/*/SKILL.md, .cursor/commands/

# フィードバックループ (B)
Hooks: .claude/settings.json, .husky/, .lefthook.yml, lefthook.yml, pre-commit (.pre-commit-config.yaml)
Linter: .eslintrc*, biome.json, .ruff.toml, .golangci.yml, rubocop.yml
テスト: jest.config*, vitest.config*, pytest.ini, go test, cargo test
CI: .github/workflows/, .gitlab-ci.yml, .circleci/, azure-pipelines.yml

# アーキテクチャ制約 (C)
型: tsconfig.json, mypy.ini, pyrightconfig.json
構造: Makefile, 依存チェック設定 (depcheck, dependency-cruiser, archunit 等)
ADR: docs/adr/, docs/decisions/

# エントロピー管理 (D)
鮮度: docs 鮮度スクリプト、renovate.json / dependabot.yml
衛生: .gitignore, .editorconfig

# 計画と実行の分離 (E)
Skills: .claude/skills/, ~/.claude/skills/
Subagent / worktree 運用: git-wt 等のラッパー、plans/ ディレクトリ

# ガードレール (F)
権限: allowed-tools 設定、MCP 許可リスト
main 保護: git hooks (pre-commit), GitHub branch protection
Secret: gitleaks.toml, .github/workflows/secret-scan*, git-secrets 設定
ループ検出: Stop hook, retry 上限ラッパー
```

#### Mode B: 大規模リポ向け Phase 1 並列化モード

Phase 1（収集）だけ `Explore` subagent に切り出して main の context window を温存する。Phase 2（評価）以降は main で実行する。

```
Agent({
  subagent_type: "Explore",
  model: "opus",
  description: "harness-audit Phase 1 現状収集（{repo_name}）",
  prompt: <<<
    リポジトリ {repo_name} のハーネス資産を網羅的に調査して構造化レポートを返す。採点はしない。

    探索対象（カテゴリ別）:
    - A. コンテキスト設計: CLAUDE.md / AGENTS.md / .cursor/rules/ / .cursorrules / .clinerules / .claude/rules/ / docs/ / docs/adr/ / .claude/skills/*/SKILL.md / .cursor/commands/
    - B. フィードバックループ: .claude/settings.json / .husky/ / .lefthook.yml / lefthook.yml / .pre-commit-config.yaml / .eslintrc* / biome.json / .ruff.toml / .golangci.yml / rubocop.yml / jest.config* / vitest.config* / pytest.ini / .github/workflows/ / .gitlab-ci.yml / .circleci/ / azure-pipelines.yml
    - C. アーキテクチャ制約: tsconfig.json / mypy.ini / pyrightconfig.json / Makefile / depcheck / dependency-cruiser / archunit / docs/adr/
    - D. エントロピー管理: renovate.json / dependabot.yml / .gitignore / .editorconfig / docs 鮮度スクリプト
    - E. 計画と実行の分離: .claude/skills/ / git-wt 等のラッパー / plans/ ディレクトリ
    - F. ガードレール: allowed-tools 設定 / MCP 許可リスト / git hooks (pre-commit) / GitHub branch protection / gitleaks.toml / .github/workflows/secret-scan* / git-secrets / Stop hook / retry 上限ラッパー

    出力形式（Markdown、各カテゴリで以下を埋める）:
    ## A. コンテキスト設計
    | パス | 種類 | 1行サマリ（行数・主要トピック・更新頻度の推測） |
    |---|---|---|

    ## B. フィードバックループ
    （以下同形式）

    制約:
    - 採点・評価・改善提案はしない（Phase 2 で main が行う）
    - 各ファイルは Read で先頭 30 行程度を確認する。全文 Read は避ける
    - パスが見つからないカテゴリは「未構成（探索したパス: ...）」と明記
    - 巨大ディレクトリ（.git / node_modules / vendor / .terraform 等）はスキップ
  >>>
})
```

main セッションは subagent の戻り値を受け取り、それを Evidence ベースとして Phase 2（評価）に進む。Phase 2 で追加の Read が必要になった場合のみ、main から個別ファイルを読む。

注意点:

- subagent が「未構成」と報告したカテゴリでも、main が念のため 1 度 grep する（subagent の探索漏れガード）
- subagent モデルは Terraform / IaC リポなど判断要素が多い場合は `opus`、軽量リポでは `sonnet` で十分
- subagent の出力サイズが大きすぎる場合は、対象カテゴリを 2 つに分けて 2 体並列で起動する（A+E / B+C+F+D など、`config/claude/rules/model-selection.md` 参照）

### 2. 6カテゴリ評価

チェックリストと共通0-5ラダーの詳細は `${CLAUDE_SKILL_DIR}/checklist.md` を参照。

| カテゴリ | 観点 |
|---------|------|
| A. コンテキスト設計 | agent-docs の品質・サイズ・段階的開示 |
| B. フィードバックループ | Hooks・リンター・テスト・CIの多層構造 |
| C. アーキテクチャ制約 | 型システムの厳格さ・構造テスト・依存方向の強制 |
| D. エントロピー管理 | ドキュメント鮮度・デッドルール・リポジトリ衛生 |
| E. 計画と実行の分離 | Skills・Subagent・レビューフロー |
| F. ガードレール | 権限制御・main 保護・ループ検出・secret scan・評価者独立性 |

各カテゴリを共通0-5ラダーで採点する（checklist.md 冒頭参照）。

- 0: 未構成 / 1: 形骸化 / 2: 手動運用 / 3: ローカル自動化 / 4: 強制ゲート / 5: 継続改善と計測

各項目は単一カテゴリに割り当てる。横断的に見える項目の主カテゴリは checklist.md の対応表で確認する。

### 3. レポート出力

```
<!-- audit-meta: {"date": "YYYY-MM-DD", "scores": {"A": N, "B": N, "C": N, "D": N, "E": N, "F": N}, "total": N} -->

## ハーネス監査レポート

リポジトリ: {name}
監査日: {YYYY-MM-DD}
総合スコア: {sum}/30
前回比: {+N / -N / ±0 / 初回}（前回 {YYYY-MM-DD}: {prev_sum}/30）

| カテゴリ | スコア | 前回比 | Confidence | Evidence | 状態 |
|---------|--------|--------|------------|----------|------|
| A. コンテキスト設計 | N | +N/-N/±0 | High/Medium/Low | {根拠ファイル:行} | {成熟度ラベル}: {1行サマリ} |
| ...全6カテゴリ... |

### 検出された課題（優先度順）

1. [カテゴリ] 課題の説明
   現状: ... (Evidence: {ファイル・設定名})
   推奨: ... (該当パターン: P{N})
   効果: ...

### Quick Wins（すぐに実行可能な改善）

- ...

### 中期的な改善提案

- ...
```

テーブル書式の指定:
- 監査日は `YYYY-MM-DD` 固定（`date "+%Y-%m-%d"` で取得）
- リポジトリ名は `basename $(git rev-parse --show-toplevel)` で取得（取得不能時は作業ディレクトリ名）
- `Evidence` 列には採点の根拠となるファイルパス・設定名を1件以上含める。空欄にしない。スコア0の場合は `searched: {探索したパス}; none found` 形式で記録する
- `Confidence` 列は High / Medium / Low。Low の場合はその理由（探索不足・運用実態未確認など）を「状態」列に追記する
- 「状態」列は `{成熟度ラベル}: {1行サマリ}` 形式。成熟度ラベルは得点に対応（5:成熟 / 4:整備済み / 3:基本構成あり / 2:部分的 / 1:最小限 / 0:未構成）
- 総合スコアには評価ラベルを付けない（数値のみ）。解釈は読み手に委ねる

Quick Wins と中期的改善の切り分け:
- Quick Wins: 既存ファイルへの数行編集 or 単一ファイル新規作成で完結。15分以内で実行可能
- 中期的改善: 新規ワークフロー整備・複数ファイル改修・運用ルール導入を伴うもの

#### レポートの保存（履歴永続化）

レポートは対象リポの `docs/audit-history/{YYYY-MM-DD}.md` に保存する。git 管理下に置くことで、チーム横断でスコア推移を diff で追える。

```bash
mkdir -p docs/audit-history
# 上記レポート全体を以下に書き込む（既存日付があれば上書き確認）
cat > "docs/audit-history/$(date '+%Y-%m-%d').md" <<'EOF'
<!-- audit-meta: ... -->
## ハーネス監査レポート
...
EOF
```

保存時の前回比計算:
- `docs/audit-history/*.md` のうち、今回より古い最新ファイルを `ls -1 docs/audit-history/*.md | sort | tail -2 | head -1` で特定
- `<!-- audit-meta: {...} -->` を grep で抽出し JSON parse（`jq -r .scores.A` など）
- カテゴリごとに今回スコアと差分を計算し、レポートの「前回比」列と冒頭サマリに反映
- 前回ファイルが存在しない場合は「初回」と表記

`audit-meta` コメントは Markdown の見た目に出ない HTML コメントなので、レポート可読性を損なわず機械可読性を確保できる。`bin/harness-audit-history` がこのコメントを parse して時系列推移を出力する。

保存パスのバリエーション:
- 既定: `docs/audit-history/`
- `docs/` が存在しない / 別目的で使われている場合: `.audit/history/` で代替
- 個人ローカルだけで運用したい場合（`gitignore` 入り）: `.audit/local/`（チーム共有はしない明示意図）

判断: 対象リポに `docs/` がすでにある（`docs/adr/` など）なら `docs/audit-history/`、なければ `.audit/history/` を作る。リポジトリ管理者の意向があれば従う。

### 4. 改善実行（ユーザー承認後）

レポート提示後、ユーザーの承認を得てから改善を実行する。

改善テンプレートは `${CLAUDE_SKILL_DIR}/patterns.md` を参照。

優先順位（課題順序付けおよび改善着手順の両方に適用）:
1. B. フィードバックループの高速化（速いフィードバックほど価値が高い）
2. F. ガードレール（main保護・破壊的操作の防止など安全装置）
3. C. アーキテクチャ制約の追加
4. A. コンテキスト設計の改善
5. E. 計画と実行の分離（Skill・Subagent整備）
6. D. エントロピー管理

ただし、深刻度が高い課題（例: 認証情報のハードコード検出・secret の git 履歴残存）は優先順位を跳ね上げる。カテゴリ順は同点時のタイブレーカーとして使う。

## Gotchas

- agent-docs のサイズだけで品質を判断しない。50行でも必要十分な場合がある
- Hooks 設定は `settings.json` や `lefthook.yml` など複数箇所に分散する。ルート直下だけ見て「未構成」と判断しない
- リポジトリ固有の技術選定を否定しない。ハーネスは既存の選択に寄り添う
- Claude Code 前提の仕組みがないからといって低く採点しない。他エージェント向けの等価成果物があれば同点で扱う
- 全カテゴリを一度に改善しようとしない。Quick Wins から段階的に
- モデルの進化で不要になる制約もある。過剰なハーネスも問題
- Confidence Low のカテゴリは追加調査を勧め、誤った改善着手を避ける
