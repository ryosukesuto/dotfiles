---
name: save-session
description: セッション状態を構造化して保存。次回セッションでの文脈復元に使う
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
---

# /save-session - セッション状態の保存

現在のセッションの作業状態を構造化して保存します。次回セッション開始時に読み込むことで、文脈の引き継ぎが可能になります。

## 使い方

- `/save-session` - 現在のセッション状態を保存
- `/save-session [メモ]` - 補足メモ付きで保存

## 処理フロー

### 1. セッションの分析

会話履歴から以下を抽出:

- 何をやろうとしていたか（目的）
- どこまで進んだか（進捗）
- 何がうまくいったか
- 何がうまくいかなかったか
- 次に何をすべきか

### 2. git状態の取得

```bash
BRANCH=$(git branch --show-current 2>/dev/null)
DIFF_STAT=$(git diff --stat HEAD 2>/dev/null)
STAGED=$(git diff --cached --stat 2>/dev/null)
RECENT=$(git log --oneline -5 2>/dev/null)
```

### 3. 保存ファイルの書き込み

プロジェクトルートの `.claude/session-state.md` に書き込む。

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SESSION_FILE="$PROJECT_ROOT/.claude/session-state.md"
mkdir -p "$(dirname "$SESSION_FILE")"
```

## 出力形式

```markdown
## Session State

Updated: YYYY-MM-DD HH:MM
Branch: feature/xxx

### Goal
このセッションで達成しようとしていたこと

### Progress
- [x] 完了したタスク
- [ ] 未完了のタスク

### What Worked
- 方法とその結果（証拠付き）

### What Did NOT Work
- 試した方法 → 失敗理由

### What Has NOT Been Tried Yet
- まだ試していないアプローチ

### Uncommitted Changes
```
git diff --stat の出力
```

### Next Step
次のセッションで最初にやるべきこと（具体的に1つ）
```

## 復元方法

次回セッション開始時に以下で文脈を復元:

```
前回の作業状態を確認して
```

Claudeは `.claude/session-state.md` を読み、前回の続きから作業を再開できます。

## 注意事項

- `.claude/session-state.md` はプロジェクトの `.gitignore` に含まれている前提
- 機密情報（APIキー、パスワード等）は記録しない
- 保存するのは作業状態のみ。知識の記録は `/til` を使う

## Gotchas

(運用しながら追記)
