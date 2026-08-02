---
name: sideline-triage
description: 副業のNotionタスク管理ハブを棚卸しする。正本(Jira/Backlog)とのステータス乖離を検出・修正し、兼務時間の制約に対して優先度の実態(High停滞)を見直す。対象サービスの具体的な識別子(データソースID・ドメイン・プロジェクトキー等)は`SKILL.local.md`を参照。「副業トリアージ」「副業タスク棚卸し」「sideline-triage」等で起動。
user-invocable: true
allowed-tools:
  - Bash(gh auth switch:*)
  - Bash(gh pr view:*)
  - mcp__notion__notion-search
  - mcp__notion__notion-fetch
  - mcp__notion__notion-query-data-sources
  - mcp__notion__notion-update-page
  - mcp__atlassian-mediphone__getJiraIssue
  - mcp__atlassian-mediphone__searchJiraIssuesUsingJql
  - mcp__backlog__get_issue
  - AskUserQuestion
---

# /sideline-triage - 副業Notionタスク棚卸し

WinTicket側の`linear-triage`と同種の棚卸しを、副業先のNotion「タスク」管理DBに対して行う。対象がLinearではなくNotionという点が異なるだけで、目的は同じ——正本との乖離を解消し、実態と乖離した優先度を整理する。

## 前提知識（ローカル設定必須）

副業先のサービス名・Notion data source ID・Jira/Backlogのドメインとプロジェクトキー・GitHub確認用アカウント名などの具体的識別子は、機密情報のためpublicリポジトリ（本ファイル）には書かない。`${CLAUDE_SKILL_DIR}/SKILL.local.md`（dotfiles-private管理）に集約している。本skill実行前に必ず読み込み、`SKILL.local.md`が存在しない・読めない場合は実行を止めてユーザーに確認する（識別子を推測で埋めない）。

兼務の時間上限（Phase 3の優先度判断の前提になる）も`SKILL.local.md`に記載している。

Notionタスク管理DBの運用方針（Notion側の親ページ本文に明記済み、URLは`SKILL.local.md`参照）:

- 開発タスクの正本(source of truth)はJira・Backlog。Notionには複製しない
- Notionは「今何をすべきか」の集約ビュー。まだJira/Backlogに起票する段階にない検討中の項目、マネジメント系(1on1・組織課題)のtodoを主に置く
- 確定した開発タスクはJira/Backlogに起票してから、Notion側は「正本リンク」プロパティに参照リンクを貼るだけにする
- タスク詳細ページは`## TODO`に`- [ ]`チェックボックスで受け入れ条件を分解、`## 進捗`に追記していく（`work-log` skillと同じ構造）

## フロー概要

```
Phase 1: タスク全件取得
Phase 2: 正本(Jira/Backlog/GitHub)との状態突合
Phase 3: 優先度の実態チェック（High停滞タスクの棚卸し）
Phase 4: 内容不明瞭・停滞タスクの事実確認
Phase 5: 承認・反映
```

## Phase 1: タスク全件取得

`mcp__notion__notion-query-data-sources`のSQLモードで全件取得する。ビューのフィルタに頼ると見落としが起きるため、ステータス・優先度・作成日を横断できる生データを一度に取る。data source URLは`SKILL.local.md`の値を使う。

```sql
SELECT "userDefined:ID" as id, "タスク名" as name, "ステータス" as status,
       "優先度" as priority, "カテゴリ" as category, "正本リンク" as link,
       "date:期限:start" as due, createdTime, url
FROM "{{SKILL.local.mdのdata source URL}}"
ORDER BY createdTime ASC
```

## Phase 2: 正本(Jira/Backlog/GitHub)との状態突合

「正本リンク」が設定されているタスクについて、リンク先の実サービスから現在の状態を取得し、Notion側のステータスと突合する。ドメイン・プロジェクトキーの対応は`SKILL.local.md`参照。

- Backlog URL: `mcp__backlog__get_issue(issueKey: "...")`
- Jira URL: `mcp__atlassian-mediphone__getJiraIssue`
- GitHub PR URL: `SKILL.local.md`記載のアカウントへ`gh auth switch`してから`gh pr view N -R <owner>/<repo> --json state,mergedAt`。確認後は必ず元のアカウントへ戻す（戻し忘れると勤務先メインリポで誤操作するリスクがある）

乖離判定:
- 正本が完了/クローズ系ステータスなのに、Notion側が未着手/進行中のまま → 更新提案
- 正本がキャンセル系ステータスなのに、Notion側が未着手/進行中のまま → 更新提案

実例（2026-08-03）: ある開発タスクが正本Backlog側では既に完了済みだったが、Notion側は3週間近く進行中のまま放置されていた。

## Phase 3: 優先度の実態チェック

副業は月あたりの稼働時間に上限があるため（`SKILL.local.md`参照）、High優先度タスクが同時に大量に積み上がっていると実行不可能な計画になる。`linear-triage`のIn Progress棚卸しトリガー（10件超で分散リスク）と同じ発想。

対象抽出: 優先度=High かつ ステータス=未着手 かつ createdTimeから2週間以上経過

各タスクをnotion-fetchで開いて内容を読み、以下の観点で妥当性を判断する。

| 観点 | 判断 |
|---|---|
| 他タスクの前提（ブロッカー）になっている | Highのまま |
| 組織的・関係構築的な重要性がある（1on1・合意形成等）かつ期限が近い外部要因がある | Highのまま |
| 単なる調査・検討タスクで即時性がない | Medium以下へ格下げ候補 |
| 期限が近い外部要因がまだ先（新入社員の入社日等） | 格下げ候補、期日が近づいたら再度Highに戻す |

実例（2026-08-03）: 13件のHigh・未着手・2〜3週間放置タスクを検出し、7件をMediumへ格下げ提案、5件はHighのまま維持（ブロッカー性・組織的重要性を理由）、1件は評価サイクル絡みでユーザー本人にしか分からない時期情報のため個別確認した。

## Phase 4: 内容不明瞭・停滞タスクの事実確認

ページ本文に「来週実施予定」等の相対的な期限表現が、記載日から2週間以上経過してもTODOが未消化のまま残っているタスクを検出する。

このようなタスクは優先度や状態を推測で変更しない。「会議が実際に開催されたか」「作業が実は完了しているか」はユーザー本人しか判断できない情報なので、`## 確認事項`セクションを追記して事実確認を促すに留める。

実例（2026-08-03）: あるタスクは「来週実施予定」（3週間前の日付で記載）のままTODOが未消化だった。優先度は据え置き、ページに確認事項を追記した。

## Phase 5: 承認・反映

Notion更新は外部システムへの書き込みであり、Claude Codeのauto-mode classifierはこの種の変更について「ユーザーが対象を名指しして承認したか」を見る。「トリアージして」という一般的な依頼だけでは、既存タスクのステータス変更・優先度変更の承認済みとはみなされない（2026-08-03に実際にブロックされた実績あり）。

1. 発見した乖離・提案を対象ID（`userDefined:ID`）と変更内容を明示した一覧で提示する
2. `AskUserQuestion`で承認を得る。件数が多い場合は「総論の方針（例: 優先度を見直すか否か）」→「具体的な提案表の提示」→「この内容で一括反映してよいか」の2段階で確認すると、1件ずつ聞くより往復が少ない
3. 承認された項目のみ`mcp__notion__notion-update-page`（`command: "update_properties"`）で反映する
4. ステータスを完了にする場合は、TODOチェックボックスの反映（`command: "update_content"`）と、進捗欄への確認日追記（`command: "insert_content"`）もセットで行う

## Gotchas

- Notionのプロパティ更新は`update_properties`コマンドで、キーはプロパティ名の日本語そのまま（例: `{"優先度": "Medium"}`）。英語に変換しない
- ステータス・優先度などの状態変更は、対象IDを名指しした上で明示承認を得てから実行する。一般的な「トリアージして」の一言だけでは承認済みとみなされない
- GitHub確認時のアカウント切り替えは作業後に必ず元へ戻す。戻し忘れは次の勤務先作業で気づかず誤操作するリスクがある
- 「来週実施予定」等の相対日付記述は、ページの`createdTime`または本文中の日付記述を基準に経過日数を計算する。記載日を確認せずに「もう終わっているはず」と推測しない
- 正本リンクが空欄の「検討中」カテゴリタスクは、まだJira/Backlog起票段階にないという運用方針上の正常状態。空欄だからといって起票を急かさない
- 担当者(person)プロパティは現状ほぼ使われていない。埋まっていないことを欠落として指摘しない
- 副業先のサービス名・ドメイン・data source ID・プロジェクトキー等の具体的識別子は本ファイルに書かない。既に書いてしまった場合は`SKILL.local.md`へ移す（2026-08-03、当初は副業先固有の名前・具体的識別子込みでpublicリポジトリに作成してしまい、ユーザー指摘で現在の名前に改名し識別子を分離した経緯あり）
