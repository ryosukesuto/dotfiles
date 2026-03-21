---
name: cc-upgrade
description: Claude Codeのchangelogを調査して設定・Skillを改善。「cc-upgrade」「changelog調査」「設定改善」「バージョン確認」等で起動。
user-invocable: true
argument-hint: "<version...> (例: v2.1.79 v2.1.80 v2.1.81)"
allowed-tools:
  - WebFetch
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Bash
  - Agent
  - AskUserQuestion
---

# /update-claude-settings - Changelogから設定・Skillを改善

指定バージョンのchangelogを調査し、現在の設定・Skillに適用できる改善点を特定・提案・実装する。

## 実行手順

### 1. バージョン特定

引数でバージョンが指定されていればそれを使う。未指定の場合:

```bash
claude --version
```

で現在のバージョンを取得し、直近3バージョン程度を対象にする。

### 2. Changelog取得

各バージョンのchangelogを並列でWebFetchする:

```
https://github.com/anthropics/claude-code/releases/tag/{version}
```

抽出する情報:
- New Features（設定・Skill・statuslineに関連するもの）
- Improvements（パフォーマンス、UX改善）
- Changes（破壊的変更、デフォルト変更）
- Bug Fixes（既存の回避策が不要になるもの）

### 3. 現在の設定を収集

並列で読み込む:
- `~/.claude/settings.json` — メイン設定
- `~/.claude/statusline.py` — statuslineスクリプト
- `~/.claude/skills/*/SKILL.md` — 全Skillのフロントマター

### 4. 改善点の照合・分類

changelogの各項目を現在の設定と照合し、以下に分類:

| 分類 | 説明 | 例 |
|------|------|-----|
| 設定追加 | 新しい設定項目が使える | `showClearContextOnPlanAccept` |
| 設定簡素化 | 既存の回避策が不要に | 組み込みrate_limitsフィールド |
| Skill改善 | Skillのfrontmatterや手順を更新 | `effort` frontmatter追加 |
| 認識のみ | 対応不要だが知っておくべき | MCP結果の折りたたみ |

### 5. 改善リストを提示

優先度付きのリストをユーザーに提示する。各項目に:
- 何が変わったか（changelog要約）
- 現在の設定への影響
- 推奨アクション

### 6. 実装

ユーザーが選択した項目を実装する。変更前に必ず対象ファイルをReadしてから編集。

## Gotchas

- changelogのURLが404になる場合がある。タグ名の形式は `v2.1.79` だが、リリースが存在しない場合はスキップする
- settings.jsonのsymlink先（dotfilesリポジトリ）を編集すること。`~/.claude/settings.json` を直接編集すると symlink が壊れる場合がある
- `rate_limits` のようなstatusline入力JSONのフィールド名は、ドキュメントと実際のフィールド名が異なることがある。ブログ記事やソースコードで実際の構造を確認する
- Skill frontmatterの `effort` など新機能は、公式ドキュメントにまだ記載されていない場合がある。changelogの記述とコミュニティの使用例を照合する
- 設定変更後はstatuslineやhookが正しく動作するかテストする。特にstatuslineはモックJSONを流し込んで確認
