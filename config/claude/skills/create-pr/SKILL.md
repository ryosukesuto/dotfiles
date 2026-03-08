---
name: create-pr
description: git diffを分析して包括的なPull Requestを自動作成。「PR作って」「PR作成」「PRお願い」「プルリク」等で起動。
user-invocable: true
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

### 0. ブランチ状態の確認と worktree 作成

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

### 1. 変更内容の分析

```bash
git status
git diff --cached
git diff
git log --oneline -10
git branch --show-current
```

### 2. 変更タイプの自動判定

- 変更規模: 追加/削除行数、ファイル数
- 変更タイプ: feat/fix/refactor/docs/test/chore
- 影響範囲: 変更ファイルの依存関係
- Breaking Change: API変更、設定変更、削除されたメソッド

### 3. Mermaid図の生成（必要に応じて）

アーキテクチャ変更、APIエンドポイント変更、状態管理変更が検出された場合に図を生成。

### 4. テストとチェックの実行

プロジェクトタイプに応じたテストコマンドを検出して実行。

### 5. PR本文の生成

```markdown
## 概要
[1-2行で変更の目的を説明]

## 変更内容
- [主要な変更点を箇条書き]

## 変更の可視化
[必要に応じてMermaid図を挿入]

## チェックリスト
- [ ] テストが全て通過
- [ ] Lintエラーなし
- [ ] 型チェック通過

## Test plan
- [ ] POST-MERGE: [マージ後に確認する項目]

## テスト結果
[テスト実行結果を挿入]

## 影響範囲
- 影響を受けるファイル: X files
- 追加行数: +XXX
- 削除行数: -XXX
```

### 6. Codex Review（必須）

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

レビュー結果をユーザーに報告し、以下を判断する:
- P0/P1の指摘がある場合: 修正してから次のステップへ進む
- P2以下のみ: ユーザーに報告し、対応要否を確認してから次のステップへ進む
- 指摘なし: そのまま次のステップへ進む

### 7. PRの作成

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
    th "PR #${PR_NUMBER} 作成完了: ${PR_URL}"
fi

# worktree内の場合は削除方法を案内
if [ -f ".git" ]; then
    BRANCH=$(git branch --show-current)
    echo ""
    echo "PRがマージされたら以下でworktreeを削除できます:"
    echo "  git wt -d $BRANCH"
    echo ""
    echo "または /sync-default-branch-and-clean で一括クリーンアップ"
fi
```

## オプション

- `--draft` - ドラフトPRとして作成

## 使用例

```bash
/create-pr
/create-pr "feat: ユーザー認証機能の追加"
/create-pr --draft
```

## worktree環境での動作

### デフォルトブランチで作業開始した場合

1. 変更内容を stash
2. `git wt <branch-name>` で worktree を作成
3. worktree 内で stash を適用: `git stash pop`
4. 作業を続行

### worktree内でPR作成後

PRがマージされたら以下で削除:

```bash
git wt -d <branch-name>   # 安全な削除
git wt -D <branch-name>   # 強制削除
```

または `/sync-default-branch-and-clean` で一括クリーンアップ

## 注意事項

1. コミット前の確認: 機密情報が含まれていないか確認
2. テスト実行: PR作成前に必ずテストを実行
3. ブランチ名: 意味のある名前を使用
4. worktree優先: デフォルトブランチでの作業は worktree を使用
5. worktree削除: PRマージ後は worktree の削除を忘れずに
6. checklist completion: リポジトリで task-list-checker が有効な場合、PR body 内の未チェックのチェックボックス（`- [ ]`）があると CI が通らない。マージ後に確認する項目には `POST-MERGE:` プレフィックスを付けること（例: `- [ ] POST-MERGE: Pod が正常起動することを確認`）。`POST-MERGE:` または `N/A` タグ付きの項目はスキップされる
