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

で現在のバージョンを取得する。「直近3バージョン」= 現在版を含む最新3リリース（例: 現在版が v2.1.116 なら v2.1.114 / v2.1.115 / v2.1.116）。

### 2. Changelog取得

各バージョンのchangelogを並列で取得する。どちらでも可:

- `WebFetch https://github.com/anthropics/claude-code/releases/tag/{version}`
- `gh release view {version} --repo anthropics/claude-code`

抽出する情報:
- New Features（設定・Skill・statuslineに関連するもの）
- Improvements（パフォーマンス、UX改善）
- Changes（破壊的変更、デフォルト変更）
- Bug Fixes（既存の回避策が不要になるもの）

404 の扱い: 該当バージョンのタグが存在しない場合は 1 つ古いバージョンに遡って3本揃える（例: v2.1.115 が 404 → v2.1.113 を追加）。遡ってもなお揃わない場合は、揃わないまま続行してその旨を提示する。

### 3. 現在の設定を収集

並列で読み込む:
- `~/.claude/settings.json` — メイン設定
- `~/.claude/statusline.py` — statuslineスクリプト（存在しない場合はスキップ）
- 全 Skill の frontmatter（方法は下記）

全 Skill の frontmatter 取得手順:

1. `Bash: ls ~/.claude/skills/` で skill ディレクトリ名一覧を取得（Glob は symlink 解決に失敗することがあるため Bash を使う）
2. 各ディレクトリの `SKILL.md` を `Read` で読み込む、または `Bash: head -20 ~/.claude/skills/*/SKILL.md` で frontmatter 部分のみ抽出

### 4. 改善点の照合・分類

changelogの各項目を現在の設定と照合し、以下に分類:

| 分類 | 説明 | 例 |
|------|------|-----|
| 設定追加 | 新しい設定項目が使える | `showClearContextOnPlanAccept` |
| 設定簡素化 | 既存の回避策が不要に | 組み込みrate_limitsフィールド |
| Skill改善 | Skillのfrontmatterや手順を更新 | `effort` frontmatter追加 |
| 認識のみ | 対応不要だが知っておくべき | MCP結果の折りたたみ |

### 5. 改善リストを提示

優先度の高い順に並べて提示する。優先度の基準は「設定追加 > 設定簡素化 > Skill改善 > 認識のみ」（影響範囲と実装容易さのバランス）。同カテゴリ内は推奨強度（高/中/低）で並べる。

各項目に:
- 何が変わったか（changelog要約）
- 現在の設定への影響
- 推奨アクション

最後に「どれを実装しますか」の選択肢を提示して止まる（番号指定 / 全実装 / 今回スキップ の3択）。

### 6. 実装

ユーザーが選択した項目を実装する。変更前に必ず対象ファイルをReadしてから編集。

## Gotchas

- changelogのURLが404になる場合がある。タグ名の形式は `v2.1.79` だが、リリースが存在しない場合はスキップする
- settings.jsonのsymlink先（dotfilesリポジトリ）を編集すること。`~/.claude/settings.json` を直接編集すると symlink が壊れる場合がある
- `rate_limits` のようなstatusline入力JSONのフィールド名は、ドキュメントと実際のフィールド名が異なることがある。ブログ記事やソースコードで実際の構造を確認する
- Skill frontmatterの `effort` など新機能は、公式ドキュメントにまだ記載されていない場合がある。changelogの記述とコミュニティの使用例を照合する
- 設定変更後はstatuslineやhookが正しく動作するかテストする。特にstatuslineはモックJSONを流し込んで確認
