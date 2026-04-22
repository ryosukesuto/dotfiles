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

以下を並行で調査する。ファイルが存在しない項目はスキップし、「未構成」として記録する。Claude 固有パスは例示であり、他エージェント（Cursor / Cline / Codex / Aider など）の等価成果物も同等に扱う。

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
## ハーネス監査レポート

リポジトリ: {name}
監査日: {YYYY-MM-DD}
総合スコア: {sum}/30

| カテゴリ | スコア | Confidence | Evidence | 状態 |
|---------|--------|------------|----------|------|
| A. コンテキスト設計 | N | High/Medium/Low | {根拠ファイル:行} | {成熟度ラベル}: {1行サマリ} |
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
