---
name: cross-repo
description: 任意の兄弟リポジトリのCLAUDE.md・ルール・設計ドキュメントを必要な分だけ参照する。「cross repo」「別リポ参照」「他リポのCLAUDE.md」「兄弟リポのルール確認」等で起動。
argument-hint: "<repo-name> [topic]"
user-invocable: true
allowed-tools:
  - Bash(ghq:*)
  - Bash(ls:*)
  - Bash(find:*)
  - Bash(wc:*)
  - Read
  - Glob
  - Grep
---

# /cross-repo - 兄弟リポジトリ参照

ghq 配下の兄弟リポジトリから、必要なファイルだけをオンデマンドで読む。
現在の作業ディレクトリや worktree の位置には依存せず、`ghq root` ベースの絶対パスで対象リポジトリを解決する。

## 実行手順

### 0. 必要時のみリファレンスを読む

必要なときだけ以下を参照する:

- `${CLAUDE_SKILL_DIR}/reference.md` — パス解決、探索レベル、停止条件
- `${CLAUDE_SKILL_DIR}/repos.local.md` — repo 別の alias、優先ルール、docs の入口

`repos.local.md` は dotfiles-private からのシンボリックリンクを想定する。
shared なファイルには実在 repo の一覧を持ち込まない。
`repos.local.md` が存在しない・読めない場合は alias 解決を無効化し、明示の `org/repo` のみ受け付ける。

### 1. 対象リポジトリを決める

優先順位:

1. ユーザーが明示した `org/repo`
2. `${CLAUDE_SKILL_DIR}/repos.local.md` の alias
3. 会話中で一意に特定できる短縮名

対象が曖昧なら推測で進めない。
同じ alias が複数 repo に一致する場合は `org/repo` の明示を要求する。

### 2. ghq root ベースで絶対パスを作る

worktree 内では `../` が元リポジトリの兄弟ではなく `.worktrees/` の兄弟を指すため、相対パスでの解決は破綻する。
ghq root は環境によらず一定なので、常にこれを起点にする。

```bash
GHQ_ROOT=$(ghq root)
TARGET_REPO_DIR="${GHQ_ROOT}/github.com/${TARGET_REPO}"
```

- `../` で親ディレクトリを辿らない
- `pwd` 基準の相対パスを使わない
- worktree 内でも同じ手順で解決する

### 3. clone 済みか確認する

対象 repo がローカルに存在しない場合は中断し、次を提案する:

```bash
ghq get "github.com/${TARGET_REPO}"
```

未 clone のまま内容を推測しない。

### 4. 3 段階で必要な分だけ読む

コンテキスト消費を最小化するため、段階的に掘り下げる。CLAUDE.mdだけで済むケースが大半。

#### Level 1: CLAUDE.md

まず `TARGET_REPO_DIR/CLAUDE.md` だけを読む。
依頼に必要な情報がそこにあれば、その時点で止める。

#### Level 2: rules 関連

`CLAUDE.md` だけでは足りない場合のみ、`${CLAUDE_SKILL_DIR}/repos.local.md` に書かれた rules の入口から 1-2 ファイル読む。
入口がなければ、repo 内で rule / guideline / convention に該当するファイルを絞って読む。

#### Level 3: docs 深掘り

さらに不足する場合のみ、依頼トピックに関係する `docs/` 配下の設計・運用ドキュメントを 1-2 ファイル読む。
全ドキュメントをまとめて読まない。

### 5. 必要な要点だけ返す

回答では以下を簡潔に整理する:

- 対象 repo
- 実際に参照したファイル
- 依頼に関係する要点
- まだ不足していて次に読むべきファイル

## 引数なしで呼ばれた場合

`org/repo` または alias の指定を求めて停止する。
`repos.local.md` の全一覧を自動表示しない（private 情報のため）。

## Gotchas

- cross-repo 参照で最も壊れやすいのはパス解決。必ず `ghq root` ベースで絶対パスを組み立てる
- 最初から rules や `docs/` を広く読まない。`CLAUDE.md` から始める
- `repos.local.md` は機密寄りの運用データなので shared 側に実 repo 名を書かない
- repo が特定できない、未 clone、候補ファイルが多すぎる、のいずれかなら無理に進めない
