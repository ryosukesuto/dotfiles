---
name: review-pr
description: PRを体系的にレビューして実行可能なフィードバックを提供
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# /review-pr - 体系的なPRレビュー

このPRを体系的にレビューし、実行可能なフィードバックを提供してください。

> バイブコーディング用: `/vibe-review pr`

## 実行手順

### 0. リファレンス読み込み（必要時のみ）

レビュー観点や評価基準の詳細が必要な場合のみ、以下を参照する。毎回読み込む必要はない:
- `${CLAUDE_SKILL_DIR}/review-pr-reference.md` — 優先度分類の詳細、技術スタック別の観点

### 1. PR情報の取得

```bash
gh pr view --comments
gh pr diff
gh pr checks
```

### 1.5 既存レビューコメントの取得

PRに既にレビューコメントがついている場合、内容を把握してからレビューに入る。

```bash
# PRのレビューコメント（コード行への指摘）を取得
gh api "repos/{owner}/{repo}/pulls/$(gh pr view --json number -q .number)/comments" \
  --jq '.[] | "[\(.user.login)] \(.path):\(.original_line // .line) - \(.body[0:200])"'
```

取得したコメントは以下の用途で使う:
- 既に指摘済みの問題を重複して報告しない
- 未解決のコメント（議論中・対応待ち）があれば、自分の判断を添える
- 既存コメントの指摘が妥当か、過剰かの評価にも使う

### 2. Codex分析の実施（必須）

既存のレビューコメントや承認状況に関わらず、必ずCodex分析を実行すること。
スキップは禁止。独自の視点を得るため、他のレビュー結果に依存しない。

#### 2a. レビュー前提の読み込み

`.claude/review-context.md` が存在する場合、内容を読み込んでCodexプロンプトに組み込む。
ファイルがなければこのステップはスキップし、デフォルトのプロンプトを使う。

```bash
REVIEW_CONTEXT=""
if [[ -f ".claude/review-context.md" ]]; then
  REVIEW_CONTEXT=$(cat .claude/review-context.md)
fi
```

#### 2b. Codex実行

まず `pane-manager.sh ensure` を実行する。バックエンドは `$CMUX_SOCKET_PATH` → `$TMUX` の順で自動検出される。
環境判定を自前で行わないこと（`echo $TMUX` 等は禁止）。

review-context.md がある場合のプロンプト:

```
gh pr diffをレビューしてください。
このrepoの実運用前提で、実害のある問題だけをP0-P3で分類してください。
前提:
{review-context.md の内容}
各指摘は [PX] file:line - 問題の要約 の形式で報告してください。
```

review-context.md がない場合のプロンプト:

```
gh pr diffをレビューしてください。P0-P3の優先度で問題を分類し、各指摘は [PX] file:line - 問題の要約 の形式で報告してください。
```

```bash
PANE_MGR=~/.claude/skills/codex-review/scripts/pane-manager.sh

$PANE_MGR ensure
$PANE_MGR send "{上記で組み立てたプロンプト}"
$PANE_MGR wait_response 180
$PANE_MGR capture 300
```

`$PANE_MGR ensure` が失敗した場合（tmux/cmux外）のみ `codex exec` にフォールバック:

```bash
codex exec "{上記で組み立てたプロンプト}"
```

### 2.5 Codex指摘の検証（必須）

Codex が技術的な主張をした場合、レビューに含める前に必ず検証する：

- 「〜はサポートしていない」「〜は動作しない」系の指摘 → 公式ドキュメントで裏取り
- 設定やコードの問題指摘 → 該当ファイルを実際に読んで確認
- 不明・検証困難な場合 → P0/P1 として断定せず「要確認」として保留

### 3. 統合レビューの作成

Codex分析、あなた自身の評価、既存レビューコメントを統合し、以下のフォーマットで出力。

既存コメントの扱い:
- 指摘済みの問題 → レビュー結果から除外（重複しない）
- 未解決の議論 → 自分の見解を「既存コメントへの補足」セクションで述べる
- 誤った指摘 → 理由を添えて訂正を提案する

## 出力フォーマット

`${CLAUDE_SKILL_DIR}/review-pr-reference.md` の出力フォーマットに従う。

## 優先度の判断基準

| 優先度 | 内容 | 例 |
|--------|------|-----|
| P0 | マージ前に必須 | セキュリティ脆弱性、データ損失、重大なバグ |
| P1 | 次のサイクルで対応 | パフォーマンス問題、エラーハンドリング不足 |
| P2 | いずれ修正 | 設計改善、保守性向上、ドキュメント |
| P3 | 余裕があれば | 命名改善、軽微なリファクタリング |

## 重要な原則

- Codex指摘を鵜呑みにせず妥当性を検証
- False Positive（AI誤検知）は除外
- プロジェクト固有の文脈・制約を考慮
- 最終的なレビュー内容はあなたが責任を持って決定

## Reader Testing（大規模PR向け、任意）

300行以上のPRでは `${CLAUDE_SKILL_DIR}/review-pr-reference.md` のReader Testingを参照。

## 新規ディレクトリ作成時の追加チェック（必須）

PRで新規ディレクトリが作成されている場合、`${CLAUDE_SKILL_DIR}/review-pr-reference.md` の追加チェックを実施。

## Gotchas

(運用しながら追記)
