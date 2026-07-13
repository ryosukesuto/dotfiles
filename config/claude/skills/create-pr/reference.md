# create-pr リファレンス

## PR本文テンプレート

必須セクションは `概要 / 変更内容 / Test plan / Linear` の4つ。それ以外は「該当する場合のみ」格下げ。空欄や `N/A` で残さず、不要なら削る。目安は 30-50 行。

### 必須テンプレート（最小構成）

```markdown
## 概要
[1-2行で変更の目的を説明]

## 変更内容
- [主要な変更点を3-5項目]

## Test plan
- [ ] [この PR で確認する項目]
- [ ] POST-MERGE: [マージ後に確認する項目]

## Linear

Closes PF-XXXX
```

`Linear` セクションはPR本文の末尾に置く（GitHub-Linear連携がMagic Wordを検出する位置のため、概要直後には置かない）。中身は `Closes` / `Refs` の判定結果のみ（詳しくは下記「Linear Issue連携」節）。

### 任意セクション（該当時のみ追加）

- `## 変更の可視化`: アーキテクチャ・データフロー・状態遷移に変更がある時のみ Mermaid 図を挿入。差分から自明な変更には付けない
- `## テスト結果`: ローカル実行のログを貼ると判断材料になる場合のみ。CI で同じテストが走るなら CI のリンクで足りるので省略
- `## 代替案`: 設計判断で複数選択肢を比較する必要がある時のみ、1-2行で「案 X は ◯◯ のため採用せず」と書く。試行錯誤の経緯は書かない（SKILL.md の Gotchas 参照）

### 書かないセクション

- `## チェックリスト`（lint pass / typecheck pass / format済）: CI が自動検証する項目を PR 本文に宣言しない
- `## 影響範囲`（変更ファイル数・追加/削除行数）: `git diff` を見れば分かる機械的情報は書かない
- 内部プロセスの記述（Codex review 状況、スキル実行ログ、レビュー段階の符号）: SKILL.md の Gotchas 参照

## オプション

- `--no-draft` - 通常PR（非draft）として作成。デフォルトはdraft

## 使用例

```bash
/create-pr                              # draft PRを作成（デフォルト）
/create-pr "feat: ユーザー認証機能の追加"  # タイトル指定でdraft PR作成
/create-pr --no-draft                   # 通常PRとして作成
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
    --draft \
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

### Closes / Refs の判定

`get_issue` で取得したIssueの Acceptance Criteria（またはdescription内のTODOリスト）を確認し、このPRで全項目を満たすかどうかで書き分ける。1つでも残るなら `Refs`、最終PRで `Closes` に切り替える。

| Magic Word | 効果 | 使う場面 |
|---|---|---|
| `Closes` | マージで自動的にIssueがDoneになる | この PR でAcceptance Criteriaを全て満たす場合 |
| `Refs` | リンクのみ、ステータス変化なし | 部分対応・複数PRにまたがる中間PRの場合 |

```markdown
## Linear

Closes PF-XXXX
```

```markdown
## Linear

Refs PF-XXXX
```

- 判断系Issue（成果物がPRでなく「決定」「整理」等）の場合はマジックワードを使わず、Linearセクション自体を省略する
- PF-XXXXが紐づかない場合（ユーザーがスキップした場合）もLinearセクションを省略する
- 複数PRにまたがると分かった時点で、Issue粒度の見直し（親Issue + 子Issueへの分割）をユーザーに提案する

### PR作成後のIssueステータス更新

GitHub-Linear連携が有効なら、PRの open/ready for review/merged に応じてIssueステータスは自動遷移する（`merged` は上記Magic Wordが前提）。連携が機能していない場合のフォールバックとして、PR作成後に手動更新してもよい:

```
mcp__linear-server__save_issue(id: "PF-XXXX", state: "In Review")
```

- Issueが既にDone/Cancelledの場合はスキップ
- `In Review` ステータスがチームに存在しない場合はスキップ
- draft PRの場合、自動連携ではまだ `In Progress` 段階（`In Review` は `ready for review` 後）のため、手動更新するなら `In Progress` のままにする

## 注意事項

1. コミット前の確認: 機密情報が含まれていないか確認
2. テスト実行: PR作成前に必ずテストを実行
3. ブランチ名: 意味のある名前を使用
4. worktree優先: デフォルトブランチでの作業は worktree を使用
5. worktree削除: PRマージ後は worktree の削除を忘れずに
6. checklist completion: リポジトリで task-list-checker が有効な場合、PR body 内の未チェックのチェックボックス（`- [ ]`）があると CI が通らない。マージ後に確認する項目には `POST-MERGE:` プレフィックスを付けること（例: `- [ ] POST-MERGE: Pod が正常起動することを確認`）。`POST-MERGE:` または `N/A` タグ付きの項目はスキップされる
7. gh アカウント確認: WinTicket org配下のリポジトリでは `gh pr create` 前に `gh auth status` でアクティブアカウントが `ryosukesuto` か確認する（mediphone作業用の `ryosukesuto-mp` のままだと401になる）
