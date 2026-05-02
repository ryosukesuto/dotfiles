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

### 粒度のシグナル

以下に該当する Issue は粒度過大の可能性が高い。着手前・週次レビュー時に検出して分割を検討する。

| シグナル | 例 | 対処 |
|---|---|---|
| タイトルに `+` `と` `および` で複数タスクが同居 | `linear-triage Phase 7 試行 + ops harness-audit ベースライン取得` | 別 Issue に分割。完了条件もそれぞれ独立する |
| チェックリストが10項目超 + PR が複数紐づく | `wizbot導入` (33項目、9 PR) | 実態は親 Issue。残タスクを子 Issue に切り出して本体は完了で閉じる |
| 親Issueでない（`parentId` なし）のに `no-est` で子もない | `Phase 0: Hermes ローカル動作確認` | DoD から estimate を付ける、または複数PRに分かれるなら子化する |
| estimate が現状と乖離（3pt なのに10 PR以上紐づく） | 同上 wizbot導入 | Issue を完了させて新しい単位で起票し直す |

判定タイミング:
- 着手前: ブランチを切る前に「この Issue は1 PR で閉じきれるか」を自問する
- 週次レビュー: `In Progress` / `Todo` のうち上記シグナルに該当するものを抽出
- 月次レビュー: estimate なしの Issue を一覧化して付与 or 分割

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

### Closes / Refs の使い分け

Magic Word は「この PR をマージしたら Issue を Done にしてよいか」で選ぶ。受け入れ条件を全て満たさないのに `Closes` を書くと、TODO が残ったまま Issue が Done になる事故が起きる。

| Magic Word | 効果 | 使う場面 |
|---|---|---|
| `Closes` / `Fixes` / `Resolves` | merge で Issue が自動 Done | この PR で Issue の受け入れ条件を全て満たす場合 |
| `Refs` / `Part of` | リンクのみ。Status 変化なし | 部分対応・複数 PR にまたがる場合の中間 PR |

判定基準: PR を開く前に Issue の Acceptance Criteria（または description の TODO リスト）を読み返し、この PR で全項目チェックが入るかを確認する。1 つでも残るなら `Refs`、最終 PR で `Closes` に切り替える。

複数 PR にまたがると分かった時点で Issue 粒度を見直す（親 Issue + 子 Issue に分割）ほうが、`Refs` を使い続けるより運用が楽になる。

### 判断系 Issue は PR 紐付けを期待しない

成果物が PR ではなく「判断」「整理」「リスクアセスメント結果」「Go/No-Go 決定」になる Issue は、自動連携の対象外として扱う。

該当する Issue:
- 「〜を判断する」「〜要否を整理する」「〜の運用判断」のようなタイトル
- 完了条件が「決定が記録されている」「フィードバックが集約されている」など、コード変更を伴わないもの

運用ルール:
- description の先頭に注記を入れる: `> 判断系Issue: 成果物は<決定内容>。PR紐付け不要、Doneは手動。`
- magic word は使わない（PR がないので Closes も Refs も無関係）
- linear-triage で PR 未紐付けと検出されてもノイズとして無視できる
- Done への遷移は手動（決定が確定したタイミングで本人が閉じる）

なぜ注記を入れるか: ラベルでの分類は他チームへの影響があるため避ける。description の注記なら個人運用で完結し、後から見た自分や他人がすぐ「PR を待つ Issue ではない」と判断できる。

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
