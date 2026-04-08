# cross-repo reference

`/cross-repo` の詳細ルール。
`SKILL.md` は薄く保ち、このファイルには運用判断だけを書く。

## 目的

兄弟リポジトリの文脈を、必要な分だけ取りに行く。
主目的は以下の 3 つ:

- 現在の変更に影響する `CLAUDE.md` の確認
- 実装やレビュー判断に必要なルールの確認
- 依頼トピックに限った `docs/` の深掘り

## 基本方針

- 起点は常に `CLAUDE.md`
- 足りないときだけ rules、その次に `docs/`
- 一括読み込みはしない
- パス解決は常に `ghq root` ベース
- 実 repo 名のマップは `repos.local.md` にだけ置く

## repos.local.md の扱い

実 repo 名を含むマップは `${CLAUDE_SKILL_DIR}/repos.local.md` に置く。
このファイルは dotfiles-private からシンボリックリンクで供給する想定。

`repos.local.md` は Markdown テーブルで十分。
Claude が自然言語で読めればよく、構造化フォーマットの厳密なパースは前提にしない。

最低限ほしい列:

| 列 | 内容 |
|----|------|
| repo | `org/repo` 形式 |
| aliases | 短縮名や会話で出やすい呼び方 |
| rules | 最初に見るディレクトリや代表ファイル |
| docs | 深掘り時の入口 |
| notes | 人間向けの短い補足 |

## パス解決

対象 repo の絶対パスは必ず以下で求める。

```bash
GHQ_ROOT=$(ghq root)
TARGET_REPO_DIR="${GHQ_ROOT}/github.com/${TARGET_REPO}"
```

`TARGET_REPO` は `org/repo` 形式を前提とする。
worktree 内でも通常 clone 内でも、同じ式を使う。

## 未 clone の扱い

`$TARGET_REPO_DIR` が存在しない場合は、それ以上読みに行かない。
次を提案して終了する。

```bash
ghq get "github.com/${TARGET_REPO}"
```

## 参照レベル

### Level 1: CLAUDE.md

最初に読むのは `TARGET_REPO_DIR/CLAUDE.md` のみ。
ここで十分なら止める。

### Level 2: rules 関連

`CLAUDE.md` だけでは足りないときに進む。

優先順位:

1. `repos.local.md` に書かれた rules の入口
2. repo 内で rule / guideline / convention を含むファイル名

この段階でも 1-2 ファイルまでに絞る。

### Level 3: docs 深掘り

依頼トピックに設計背景が必要なときだけ進む。

優先順位:

1. `repos.local.md` に書かれた docs の入口
2. `docs/` 配下で依頼トピックに関係するファイル

この段階でも 1-2 ファイルまでに絞る。

## 返し方

固定テンプレートは使わない。
ただし、最低限次の情報は含める:

- どの repo を見たか
- どのファイルを読んだか
- 依頼に直接関係する要点
- まだ不足している場合の次の候補

## 停止条件

次の場合は無理に掘らず止める:

- repo が特定できない
- 同じ alias が複数 repo に一致する
- repo が未 clone
- `repos.local.md` が存在しない・読めない場合に alias で呼ばれた
- `CLAUDE.md` も rules 入口も docs 入口も見つからない
- 候補ファイルが多すぎて topic 指定なしでは絞れない

## 運用メモ

- `repos.local.md` の rules と docs には、よく見る入口だけを書けばよい
- repo ごとに完全な目録を維持しようとしない
- メンテコストを下げるため、探索順は 3 段階から増やさない
