---
name: quick-push
description: 変更を素早くコミット＆プッシュして日常作業を効率化。「push」「プッシュ」「コミットして」「上げといて」「反映して」「pushして」等で起動。
user-invocable: true
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
---

# /quick-push - 変更を素早くコミット＆プッシュ

## 目的
現在の変更を素早くコミットしてリモートにプッシュします。日常的な作業の効率化に最適です。

## 動作
1. `git status`で現在の変更を表示
2. このセッションで自分が変更・作成したファイルのみを対象にする（会話履歴から判断）
   - セッション前から存在するunstaged変更は対象外
   - 判断に迷う場合はユーザーに確認する
3. main/masterブランチの場合は `wt.allowDirectCommit` を確認（詳細は下記「main直コミット判定」）
4. 危険なファイル（.env、secrets、credentials等）を除外
5. 対象ファイルのみを`git add`
6. 変更内容を分析して適切なprefixを選択：
   - `feat:` 新機能追加
   - `fix:` バグ修正
   - `docs:` ドキュメント変更
   - `style:` フォーマット修正
   - `refactor:` リファクタリング
   - `test:` テスト追加・修正
   - `chore:` その他の変更
7. コミットメッセージを表示して確認
8. PRマージ済みチェック（push前）
9. 現在のブランチをリモートにプッシュ
10. mainブランチ以外の場合、PR作成を提案

## main直コミット判定

現在のブランチが`main`/`master`だった場合、worktree作成やブランチ切り替えを提案する前に必ず以下を確認する。

```bash
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" == "main" ]] || [[ "$current_branch" == "master" ]]; then
    allow=$(git config --get wt.allowDirectCommit 2>/dev/null)
    if [[ "$allow" == "true" ]]; then
        # そのまま直コミット可。worktree作成/ブランチ切替は提案しない
        :
    else
        # worktree作成を提案する（CLAUDE.mdのworktree必須ルール）
        echo "main直コミットはブロックされています。worktreeを作成します"
    fi
fi
```

なぜこのチェックが必要か: CLAUDE.mdは「ブランチ作業はworktree必須」と書かれているが、dotfilesなど個人リポジトリでは `wt.allowDirectCommit=true` でopt-outされている。ルールの禁止側だけ見てworktree作成に進むと、opt-outされたリポジトリで無駄なworktreeを作ってユーザーを待たせる。**worktreeフローに入る前に必ずこの設定を確認する**。

## PRマージ済みチェックの実装手順

コミット後、push前に以下のチェックを必ず実行：

```bash
current_branch=$(git rev-parse --abbrev-ref HEAD)

if [[ "$current_branch" != "main" ]] && [[ "$current_branch" != "master" ]]; then
    pr_info=$(gh pr list --head "$current_branch" --state all --json number,state,title 2>/dev/null)

    if [[ -n "$pr_info" ]] && [[ "$pr_info" != "[]" ]]; then
        pr_state=$(echo "$pr_info" | jq -r '.[0].state')
        pr_number=$(echo "$pr_info" | jq -r '.[0].number')
        pr_title=$(echo "$pr_info" | jq -r '.[0].title')

        if [[ "$pr_state" == "MERGED" ]]; then
            echo "Warning: このブランチのPRはすでにマージ済みです"
            echo "  ブランチ: $current_branch"
            echo "  PR #$pr_number: $pr_title"
            # ユーザーに確認を求める
        fi
    fi
fi
```

## 安全機能
- 機密ファイルの自動除外
- mainブランチへの直接プッシュ時は警告
- PRマージ済みブランチへのpush防止
- force pushが必要な場合は確認
- 大量のファイル変更時は要確認

## 使用例
```
/quick-push
```

## worktree環境での動作

worktree内で実行した場合、PRマージ済みチェック後に以下を提案:

```bash
# 現在のディレクトリがworktreeか確認
current_dir=$(pwd)
wt_info=$(git worktree list | grep "^$current_dir ")

if [[ -n "$wt_info" ]] && [[ "$pr_state" == "MERGED" ]]; then
    echo "このworktreeを削除しますか？"
    echo "  git-wt remove $(basename $current_dir)"
fi
```

## 注意事項
PRマージ後にエラーが発生した場合:
- マージ済みのブランチにはpushしない
- 新しいブランチを作成して、そこで修正を行う
- worktree環境の場合は、worktreeを削除してから新しいworktreeを作成

## Gotchas

- `wt.allowDirectCommit=true` のリポジトリ（dotfiles等）でworktree作成を提案しない。CLAUDE.mdの「worktree必須」はopt-out前提のルール。main/masterブランチに入ったら即座に worktree を作ろうとせず、先に `git config --get wt.allowDirectCommit` を確認する
