# create-pr リファレンス

## PR本文テンプレート

```markdown
## 概要
[1-2行で変更の目的を説明]

<!-- Linear -->
Linear: [PF-XXXX](https://linear.app/winticket/issue/PF-XXXX)

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
[並列タスクAの結果を挿入]

## 影響範囲
- 影響を受けるファイル: X files
- 追加行数: +XXX
- 削除行数: -XXX
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

## PR作成コマンド詳細

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
    echo "- $(date '+%Y/%m/%d %H:%M:%S'): PR #${PR_NUMBER} 作成完了: ${PR_URL}" >> ~/gh/github.com/ryosukesuto/obsidian-notes/$(date '+%Y-%m-%d')_daily.md
fi

# worktree内の場合は削除方法を案内
if [ -f ".git" ]; then
    BRANCH=$(git branch --show-current)
    echo "PRマージ後: git wt -d $BRANCH または /sync-default-branch-and-clean"
fi
```

## Linear Issue連携

### PR作成後のIssueステータス更新

PR作成後、紐づいたLinear Issueのステータスを `In Review` に更新する:

```
mcp__linear-server__save_issue(id: "PF-XXXX", state: "In Review")
```

- Issueが既にDone/Cancelledの場合はスキップ
- `In Review` ステータスがチームに存在しない場合はスキップ

### PR本文へのLinearリンク挿入位置

概要セクションの直後、変更内容の前に配置する:

```markdown
## 概要
[説明]

<!-- Linear -->
Linear: [PF-XXXX](https://linear.app/winticket/issue/PF-XXXX)

## 変更内容
```

PF-XXXXが紐づかない場合（ユーザーがスキップした場合）はLinearセクションを省略する。

## 注意事項

1. コミット前の確認: 機密情報が含まれていないか確認
2. テスト実行: PR作成前に必ずテストを実行
3. ブランチ名: 意味のある名前を使用
4. worktree優先: デフォルトブランチでの作業は worktree を使用
5. worktree削除: PRマージ後は worktree の削除を忘れずに
6. checklist completion: リポジトリで task-list-checker が有効な場合、PR body 内の未チェックのチェックボックス（`- [ ]`）があると CI が通らない。マージ後に確認する項目には `POST-MERGE:` プレフィックスを付けること（例: `- [ ] POST-MERGE: Pod が正常起動することを確認`）。`POST-MERGE:` または `N/A` タグ付きの項目はスキップされる
