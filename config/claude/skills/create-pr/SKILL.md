---
name: create-pr
description: git diffを分析して包括的なPull Requestを自動作成。「PR作って」「PR作成」「PRお願い」「プルリク」等で起動。
argument-hint: "[title] [--draft]"
user-invocable: true
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
  - Bash(git-wt:*)
  - Bash(gh:*)
  - Bash(~/.claude/skills/codex-review/scripts/pane-manager.sh:*)
  - Bash(codex:*)
  - Read
  - Glob
  - Grep
---

# /create-pr - スマートPR作成コマンド

git diffを分析して、Mermaid図やテスト結果を含む包括的なPull Requestを自動作成します。

## 実行手順

### 0. リファレンス読み込み（必要時のみ）

- `${CLAUDE_SKILL_DIR}/reference.md` — PR本文テンプレート、worktree環境での動作、注意事項

### 1. ブランチ状態の確認と worktree 作成

```bash
CURRENT_BRANCH=$(git branch --show-current)
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)

# デフォルトブランチで作業中の場合は worktree を作成
if [[ "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" ]]; then
    echo "デフォルトブランチで作業中です。worktree を作成します。"
    # ユーザーにブランチ名を確認
    # git wt <branch-name> で worktree を作成して移動
fi
```

### 2. 変更内容の分析

```bash
git status
git diff --cached
git diff
git log --oneline -10
git branch --show-current
```

### 3. 変更タイプの自動判定

- 変更規模: 追加/削除行数、ファイル数
- 変更タイプ: feat/fix/refactor/docs/test/chore
- 影響範囲: 変更ファイルの依存関係
- Breaking Change: API変更、設定変更、削除されたメソッド

### 4. Mermaid図の生成（必要に応じて）

アーキテクチャ変更、APIエンドポイント変更、状態管理変更が検出された場合に図を生成。

### 5-7. テスト・PR本文生成・Codexレビュー（並列実行）

以下の3つは依存関係がないため、Subagentで並列実行する。

#### 並列タスクA: テストとチェックの実行
プロジェクトタイプに応じたテストコマンドを検出して実行。結果を返す。

#### 並列タスクB: PR本文のドラフト生成
ステップ2-4の分析結果をもとにPR本文をドラフト生成する（テスト結果の欄は後で埋める）。

`${CLAUDE_SKILL_DIR}/reference.md` のPR本文テンプレートに従う。

#### 並列タスクC: Codex Review（必須）

PR作成前にCodexによるレビューを実施する。tmux/cmux環境かどうかで実行方法を切り替える。

```bash
PANE_MGR=~/.claude/skills/codex-review/scripts/pane-manager.sh

# tmux/cmux環境の判定
if [ -n "$CMUX_SOCKET_PATH" ] || [ -n "$TMUX" ]; then
    # pane-manager経由でインタラクティブレビュー
    $PANE_MGR ensure
    $PANE_MGR send "git diffを確認して、以下の観点でレビューしてください:
- P0: セキュリティ脆弱性、データ損失リスク
- P1: パフォーマンス問題、エラーハンドリング不足
- P2: 設計改善、保守性向上"
    $PANE_MGR wait_response 180 && $PANE_MGR capture 200
else
    # codex exec で単発レビュー
    codex exec "git diffを確認して、以下の観点でレビューしてください:
- P0: セキュリティ脆弱性、データ損失リスク
- P1: パフォーマンス問題、エラーハンドリング不足
- P2: 設計改善、保守性向上"
fi
```

#### 並列タスク完了後の統合

1. テスト結果をPR本文に埋め込む
2. Codexレビュー結果をユーザーに報告:
   - P0/P1の指摘がある場合: 修正してから次のステップへ進む
   - P2以下のみ: ユーザーに報告し、対応要否を確認してから次のステップへ進む
   - 指摘なし: そのまま次のステップへ進む

### 8. デフォルトブランチの最新化とリベース

PR作成前にデフォルトブランチの最新を取り込み、コンフリクトを事前に解消する。

```bash
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)
git fetch origin "$DEFAULT_BRANCH"
git rebase "origin/$DEFAULT_BRANCH"
```

- リベースでコンフリクトが発生した場合は解消してから続行する
- コンフリクトの内容をユーザーに報告し、対応方針を確認する

### 9. PRの作成

```bash
# Terraformリポジトリの場合はフォーマット実行
if [ -f "terraform.tf" ] || [ -f "main.tf" ]; then
    terraform fmt -recursive
fi

git add -A
git commit -m "feat: [簡潔な説明]"
git push -u origin HEAD

PR_URL=$(gh pr create \
    --title "[Type]: 簡潔なタイトル" \
    --body "[生成されたPR本文]" \
    --assignee @me)

# 作業報告
if [ -n "$PR_URL" ]; then
    PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
    Obsidian daily:append vault=obsidian-notes content="- $(date '+%Y/%m/%d %H:%M:%S'): PR #${PR_NUMBER} 作成完了: ${PR_URL}"
fi

# worktree内の場合は削除方法を案内（詳細は reference.md 参照）
if [ -f ".git" ]; then
    BRANCH=$(git branch --show-current)
    echo "PRマージ後: git wt -d $BRANCH または /sync-default-branch-and-clean"
fi
```

## Gotchas

(運用しながら追記)
