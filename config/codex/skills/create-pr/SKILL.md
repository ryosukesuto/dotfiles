---
name: create-pr
description: Codexでgit diffを分析し、PR本文作成、セルフレビュー、必要なcommit/push、draft PR作成まで実行する。「PR作って」「PR作成」「プルリク」「create-pr」等で起動。
---

# create-pr - Codex-native PR作成

ローカル差分を読み、レビュー可能なPull Requestを作成する。Codex自身が分析・本文作成・セルフレビューを行うため、別のCodex paneや `codex exec` は起動しない。

## 実行原則

- ユーザーが明示しない限りdraft PRを作る。
- GitHubへの書き込みはPR作成に必要な操作だけに限定する。PR本文やコメントの投稿を二重実行しない。
- 既存の未コミット変更は、今回のPRに含めるべきものだけをstageする。判断に迷うファイルは確認する。
- PR本文には作業プロセスや内部用語を書かない。レビュー者に必要な「何を変えたか」「なぜ変えたか」「どう確認したか」だけを書く。
- Codex subagentはユーザーが「並列で」「subagentで」などを明示した場合のみ使う。通常はCodexがローカルで複数パスとして分析する。

## 事前確認

```bash
git status --short --branch
git branch --show-current
git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p'
git diff --stat
git diff --cached --stat
git log --oneline -10
```

デフォルトブランチ上で変更がある場合は、このリポジトリのルールに従ってworktreeへ分離する。`wt.allowDirectCommit=true` の個人dotfiles系では直作業が許容されることがあるため、先に `git config --get wt.allowDirectCommit` を確認する。

## PR情報の組み立て

1. 差分を分析する:
   - 変更タイプ: `feat` / `fix` / `refactor` / `docs` / `test` / `chore`
   - 影響範囲: API、設定、DB、CI、CLI、ドキュメント
   - Breaking Change、移行順序、マージ後確認の有無
2. ブランチ名やコミットメッセージからIssue IDを抽出する:
   ```bash
   BRANCH=$(git branch --show-current)
   ISSUE_ID=$(echo "$BRANCH" | grep -oiE '(PF|ASICS|SRV|WT)-[0-9]+' | tail -1 | tr 'a-z' 'A-Z')
   ```
3. Linear connector/toolが使える場合だけIssueを取得し、PR本文にリンクを入れる。使えない場合はブロックせず、Issue IDが分かる範囲で本文へ入れる。
4. 変更に応じたテスト/チェックを実行する。既存のnpm/mise/Makefile/justfileを優先する。

## セルフレビュー

PR作成前にこのセッション内で差分をレビューする。別Codexやpaneは使わない。

重点観点:

- P0: セキュリティ、データ損失、本番停止、破壊的schema/API変更
- P1: 要件未達、リリース後に検出困難なバグ、運用事故、権限/同時実行/エラーハンドリング
- P2: 保守性、テスト不足、責務境界、将来の変更コスト
- P3: 命名、表現、軽微な整形

P0/P1が見つかった場合は、PR作成前に修正またはユーザー確認を行う。未確認の技術的主張を断定しない。

## PR本文テンプレート

空セクションは残さない。目安は30-50行。

```markdown
## 概要
[1-2行で変更の目的を説明]

<!-- Linear -->
Linear: [PF-XXXX](https://linear.app/winticket/issue/PF-XXXX)

## 変更内容
- [主要な変更点を3-5項目]

## Test plan
- [x] [実行した確認]
- [ ] POST-MERGE: [マージ後に確認する項目]
```

必要な場合だけ追加:

- `## 変更の可視化`: アーキテクチャ、データフロー、状態遷移が変わる時
- `## 代替案`: 設計判断の比較がレビューに必要な時
- `## リスク`: ロールアウト順、互換性、運用注意がある時

書かないもの:

- 探索・試行錯誤の経緯
- 変更ファイル数や追加/削除行数などdiffから自明な情報
- `lint pass` / `typecheck pass` / `format済` のようなCIで自動検証される宣言
- `Codexレビュー済み`、skill名、評価手法名などの内部プロセス

## 作成手順

```bash
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p')
[ -n "$DEFAULT_BRANCH" ] || DEFAULT_BRANCH=main
git fetch origin "$DEFAULT_BRANCH"
git rebase "origin/$DEFAULT_BRANCH"
```

コンフリクトが出たら解消してから続行する。Terraformリポジトリでは `terraform fmt -recursive` を実行する。

コミットが必要な場合:

```bash
git add <対象ファイルのみ>
git diff --cached --check
git commit -m "<type>: <summary>"
git push -u origin HEAD
```

PR作成:

```bash
gh pr create --draft --title "<title>" --body-file /tmp/pr-body.md --assignee @me
```

ユーザーが明示的に通常PRを希望した場合だけ `--draft` を外す。本文にコードブロックを含む場合は必ず `--body-file` を使う。

## 作成後

- PR URLをユーザーに共有する。
- Linear Issueを取得でき、かつ `In Review` への更新が適切な場合だけ更新する。Done/CancelledのIssueは触らない。
- worktree内なら、マージ後の削除方法を案内する。

## Gotchas

- `git add -A` は原則使わない。今回のPR対象だけstageする。
- PR本文で `#NNN` をそのまま書くと別Issue/PRにリンクされる。外部IDはフルURLまたは説明付きで書く。
- GitHub作成系コマンドに `|| fallback` や自動リトライを付けない。副作用のあるPOSTが二重実行される。
- PR作成前に既存PRがあるか `gh pr view` / `gh pr list --head "$(git branch --show-current)"` で確認する。
