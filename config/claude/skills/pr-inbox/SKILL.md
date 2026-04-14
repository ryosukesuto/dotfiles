---
name: pr-inbox
description: 複数リポジトリを横断して自分宛てのPRレビュー依頼とアサインを一覧化する。「PR確認」「レビュー依頼確認」「アサインPR」「pr inbox」「レビュー待ち」等で起動。
user-invocable: true
allowed-tools:
  - Bash
---

# /pr-inbox - PRレビュー依頼・アサイン確認

複数のGitHubリポジトリを対象に、自分宛てに直接レビュー依頼されているPRと自分がアサインされているPRを一覧表示する。チーム経由のレビュー依頼は対象外。

## 実行手順

### 1. ローカル設定を読む

対象リポジトリとGitHubユーザー名は `${CLAUDE_SKILL_DIR}/SKILL.local.md` に定義されている。Readで読み込んで `REPOS` と `USER` を取得する。

### 2. 各リポジトリに対してクエリを実行

リポジトリごとに以下を並列実行する（bash loopで1回にまとめる）。

```bash
for repo in $REPOS; do
  echo "=== $repo ==="
  echo "-- review requested --"
  gh search prs --repo $repo --state open "user-review-requested:$USER" \
    --json number,title,author,url 2>/dev/null
  echo "-- assigned --"
  gh search prs --repo $repo --state open --assignee $USER \
    --json number,title,author,url 2>/dev/null
done
```

`user-review-requested:` を使う理由: `--review-requested` や `review-requested:` はチーム経由の依頼も拾ってしまい、直接指名されたPRを識別できない。直接レビューだけに絞ることで「自分が見るべきPR」を明確にする。

### 3. 結果を整理して表示

リポジトリごとに以下の形式で提示する。

- レビュー依頼（直接）: PR番号、タイトル、author
- アサイン: PR番号、タイトル、author

bot発のPR（renovate、release-manager等）は別枠にまとめるか、件数だけ示す。人間発のPRを優先して見せる。古いPR（1週間以上前）は注記する。

最後に「対応優先度」を一言添える（例: 「server の #XXX が古いので状況確認推奨」）。

## Gotchas

- `review-requested:USER` はチーム経由の依頼も含むため使わない。必ず `user-review-requested:USER` を使う
- `gh search prs` の `--review-requested` フラグも同様にチーム経由を含むので避ける
- `--assignee` にはフラグ版が使える（`user-assignee:` クエリ指定子は存在しない）
- リポジトリ名（org/repo）は公開リポジトリに含めないため、必ず `SKILL.local.md` から読む。SKILL.md本体にハードコードしない
- bot発のPRが大量にあると一覧が埋もれる。renovate・release-manager・dependabotは別枠にする
