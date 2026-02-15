## Context

Claude Codeでの作業（git commit）を自動的にObsidianデイリーノートに記録したい。
現行の `th` コマンドは `## 📝 メモ` セクション固定で、実態のデイリーノート運用と乖離している。
`/til` スキルとの共存も考慮し、`th` をセクション対応に進化させた上で commit hook を実装する。

## 変更内容

### 1. `bin/th` にセクション指定機能を追加

対象: `/Users/s32943/gh/github.com/ryosukesuto/dotfiles/bin/th`

変更点:
- `--section` (`-s`) オプションを追加。セクション見出しを指定可能にする
- デフォルトは `📝 メモ`（後方互換）
- セクションが存在しなければ作成する
- 既存のawk挿入ロジックを、指定セクション対応に一般化する

使用例:
```bash
th "手動メモ"                           # → ## 📝 メモ に追記（従来互換）
th -s "🤖 Commits" "[main] fix: ..."    # → ## 🤖 Commits に追記
```

### 2. `bin/claude-commit-log` を新規作成

対象: `/Users/s32943/gh/github.com/ryosukesuto/dotfiles/bin/claude-commit-log`（新規）

処理フロー:
1. stdinからPostToolUseのJSONを読み取る
2. `tool_input.command` に `git commit` が含まれるか判定（含まれなければ即 exit 0）
3. `tool_response` から成功パターン `[branch hash]` を検出（なければ exit 0）
4. ブランチ名・コミットメッセージ・変更ファイル数を抽出
5. `th -s "🤖 Commits" "[branch] commit_msg (N files)"` を呼び出す

依存: `jq`, `th`（絶対パスで呼び出す）

エラーハンドリング:
- git commitでないBash呼び出し → 即exit 0（~1ms）
- commitが失敗した場合 → 成功パターン不在でexit 0
- `th` が失敗した場合 → `|| true` で無視
- `tool_response` の型が不明 → jqの型チェックで文字列/オブジェクト両対応

### 3. `~/.claude/settings.json` にhookを追加

対象: `/Users/s32943/gh/github.com/ryosukesuto/dotfiles/config/claude/settings.json`
（`~/.claude/settings.json` のシンボリックリンク元）

変更: `PostToolUse` 配列に Bash マッチャーを追加

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "/Users/s32943/gh/github.com/ryosukesuto/dotfiles/bin/claude-commit-log"
    }
  ]
}
```

全Bash PostToolUseでスクリプトが起動するが、git commit以外は即exit 0（~1ms）。
体感遅延が出る場合は `async: true` に切り替える余地あり。

## デイリーノートの出力イメージ

```markdown
# 2026-02-15

## 🤖 Commits
- 2026/02/15 14:30:22: [main] chore: update config (3 files)
- 2026/02/15 15:00:10: [feat/hook] feat: add commit logging (2 files)

## 📝 メモ
- 2026/02/15 15:30:00: レビュー完了

---

## 💡 Claude Code Hooks: PostToolUse pattern
#til/claude-code #til/hooks
構造化された学び記事...
```

## スコープ外

- `/til` スキルの書き込みロジック変更（現状のappend方式を維持）
- `th` の根本的なリアーキテクチャ（セクション指定追加のみ）

## 検証手順

1. `th` 単体テスト: `th -s "🤖 Commits" "テスト"` でデイリーノートに正しいセクションで書き込まれるか
2. `claude-commit-log` 単体テスト: 成功/失敗/非commitのJSON入力でそれぞれ正しく動作するか
3. Claude Code統合テスト: セッション再起動後、commitを実行してデイリーノートに記録されるか

## 対象ファイル

- `bin/th` - セクション指定機能追加（既存）
- `bin/claude-commit-log` - hook用スクリプト（新規）
- `config/claude/settings.json` - PostToolUse hook追加（既存）
