# Linear ⇔ GitHub PR 連携のためのブランチ命名規則

Linear の GitHub 連携を最大限活用するため、ブランチ名・PR タイトル・PR description に Linear Issue ID を含める。これによって手動の紐づけ作業が不要になる。

## Issue 起票のタイミング

着手前に Issue を切る。これは自動連携の前提。

- 着手前に切る → `gitBranchName` をそのまま使えるので自動リンクが即効
- 着手後に切る → ブランチ名・PR タイトルを後から書き直す必要があり、手動紐づけ作業が発生する

例外: 5分以内に終わる typo 修正など軽微な作業は Issue 不要でも可。ただしその PR は Linear と紐づかない前提で扱う。

## Issue の粒度

| 作業タイプ | Issue 設計 |
|---|---|
| 単発の機能/修正 | 1 Issue = 1 PR、`Closes` で自動 Done |
| 複数 PR またぐ施策 | 親 Issue + 子 Issue（各子を `Closes`、親は子が全部 Done になったら手動 Done） |
| 調査/Spike | 1 Issue、PR必須でない（成果物は文書） |
| 長期エピック | 親 Issue を In Progress 維持、子 Issue を順次切る |

ハーネス整備のように複数リポをまたぐ施策は、リポごとに子 Issue を切る。1 PR で閉じられる粒度になっていれば magic word での自動 Done が効く。

## ブランチ名

Linear Issue 1件に対応する作業は、Linear が割り当てる `gitBranchName` を使う。

```
suto-ryosuke/pf-1862
```

形式: `<assignee-handle>/<issue-id-lowercase>`

Linear Issue 画面の右上「Copy git branch name」ボタン、または MCP の `gitBranchName` フィールドからコピーできる。

### 例外

- ハーネス整備など Issue を切らない雑多な作業: `chore/<topic>` で良い。ただし PR 作成時に対応 Issue を後付けで決める手間が発生するため、原則は Issue を先に切る
- 個人リポ (`ryosukesuto/*`): Linear と紐づかないので任意

## PR タイトル

ブランチ名で自動リンクが効くので、タイトルへの ID 強制は不要。ただし Issue ID をタイトルに入れると Linear 上で見つけやすくなるため、慣習として推奨する。

## PR description

PR description の末尾に Magic Word を入れて、マージ時に Issue を自動 Done にする。

```markdown
## Linear

Closes PF-XXXX
```

`Closes` / `Fixes` / `Resolves` のいずれも有効。複数 Issue を1 PR で閉じる場合は `Closes PF-1234, Closes PF-1235` のように繰り返す。

### 親 Issue は閉じない

サブタスク (`parentId` がある Issue) を閉じても親 Issue は自動クローズしない。サブタスク全体が完了したら親 Issue は手動で Done にする。

## 自動遷移する Status

Linear の GitHub 連携が有効な org では、PR の状態に応じて Issue の Status が自動遷移する。

| PR | Issue |
|---|---|
| open | In Progress |
| ready for review | In Review |
| merged | Done（Magic Word 必須） |
| closed (not merged) | 何もしない |

`In Progress` / `In Review` の自動遷移は org の Linear 設定次第。WinTicket org では機能している。

## linear-triage skill との関係

Linear の自動連携が効いていれば、PR description への手動追記は不要。`linear-triage` skill の Phase 1 は「自動リンクが付かなかった PR」のみを検出すればよい。判定は Linear MCP の `get_issue(attachments)` で PR が添付されているかで行う。

## チェックの仕組み

- 個人 dotfiles の `pre-push` hook で「ブランチ名に PF-/ASICS-/SRV- 等のIssue ID を含むか」を機械チェックする運用を将来検討
- 現状は人間運用。違反したら Linear-triage で気づいて修正する
