---
description: 変更を素早くコミット＆プッシュして日常作業を効率化
---

# /quick-push - 変更を素早くコミット＆プッシュ

## 目的
現在の変更を素早くコミットしてリモートにプッシュします。日常的な作業の効率化に最適です。

## 動作
1. **変更確認**:
   - `git status`で現在の変更を表示
   - 未追跡ファイルと変更ファイルをリスト化
   
2. **自動ステージング**:
   - 変更されたファイルを分析
   - 危険なファイル（.env、secrets、credentials等）を除外
   - 安全なファイルのみを`git add`
   
3. **コミットメッセージ生成**:
   - 変更内容を分析して適切なprefixを選択：
     - `feat:` 新機能追加
     - `fix:` バグ修正
     - `docs:` ドキュメント変更
     - `style:` フォーマット修正
     - `refactor:` リファクタリング
     - `test:` テスト追加・修正
     - `chore:` その他の変更
   - 変更ファイルから意味のあるメッセージを生成
   
4. **確認プロンプト**:
   - コミットメッセージを表示して確認
   - 必要に応じて編集可能

5. **PRマージ済みチェック** (push前):
   - 現在のブランチに対応するPRを検索
   - PRがすでにマージ済みの場合は警告を表示
   - ユーザーに確認を求める（通常は新しいブランチを作成すべき）

6. **プッシュ実行**:
   - 現在のブランチをリモートにプッシュ
   - 上流ブランチが未設定の場合は`-u`オプションで設定

7. **PR作成提案**:
   - mainブランチ以外の場合、PR作成を提案

## 使用例
```
/quick-push
```

## 安全機能
- 機密ファイルの自動除外
- mainブランチへの直接プッシュ時は警告
- **PRマージ済みブランチへのpush防止**: マージ済みのPRに対応するブランチへのpush時は警告
- force pushが必要な場合は確認
- 大量のファイル変更時は要確認

## 注意事項
**PRマージ後にエラーが発生した場合**:
- マージ済みのブランチには**push しない**でください
- 新しいブランチを作成して、そこで修正を行ってください
- `/quick-push`実行時と`git push`実行時、両方でマージ済みチェックが行われます（pre-push hook）

## 実装詳細（Claude Code向け）

### PRマージ済みチェックの実装手順

コミット後、push前に以下のチェックを必ず実行してください：

```bash
# 1. 現在のブランチ名を取得
current_branch=$(git rev-parse --abbrev-ref HEAD)

# 2. main/masterブランチはスキップ
if [[ "$current_branch" != "main" ]] && [[ "$current_branch" != "master" ]]; then
    # 3. ブランチに対応するPRを検索
    pr_info=$(gh pr list --head "$current_branch" --state all --json number,state,title 2>/dev/null)

    # 4. PRが存在し、かつマージ済みかチェック
    if [[ -n "$pr_info" ]] && [[ "$pr_info" != "[]" ]]; then
        pr_state=$(echo "$pr_info" | jq -r '.[0].state')
        pr_number=$(echo "$pr_info" | jq -r '.[0].number')
        pr_title=$(echo "$pr_info" | jq -r '.[0].title')

        if [[ "$pr_state" == "MERGED" ]]; then
            # 5. マージ済みの場合は警告を表示
            echo "⚠️  WARNING: このブランチのPRはすでにマージ済みです"
            echo "  ブランチ: $current_branch"
            echo "  PR #$pr_number: $pr_title"
            echo "  状態: MERGED"
            echo ""
            echo "通常、マージ済みのブランチにはpushしません。"
            echo "新しい変更の場合は、新しいブランチを作成することを推奨します。"
            echo ""
            echo "それでもpushを続行しますか？ (通常はキャンセルすべきです)"
            # ユーザーに確認を求め、Noの場合はpushをスキップ
        fi
    fi
fi
```

**重要**:
- このチェックは`git push`の**直前**に実行してください
- pre-push hookも同じチェックを行いますが、コマンド内でも明示的に確認することで二重の安全性を確保します