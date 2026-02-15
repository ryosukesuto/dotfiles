---
name: linear-workflow
description: Linearでのissue作成・ポイント見積もり・サイクル管理のガイドライン。「issueを作って」「ポイント見積もり」「サイクル確認」「Linear MCP」等で起動。
user-invocable: false
---

# Linearタスク管理ワークフロー

チームのタスク管理ガイドライン。
Linearを「タスク管理ツール」から「意思決定ログ」に変える。

## タスク・プロジェクトの作成

### プロジェクト作成基準
- 複数サイクルにまたがる → Linearプロジェクトとして作成
- プロジェクトには原則ゴールとマイルストーンを設定
- 工数が読みづらい場合でも、期限は一旦決めでOK

### プロジェクト必須項目

Project Descriptionに以下を必ず記載：

| 項目 | 内容 | 例 |
|------|------|-----|
| 完了条件 | 状態で書く（完了形） | 新構成が本番反映済み、旧構成が削除済み |
| スコープ外 | やらないこと（1行） | 監視基盤の刷新までは含まない |

完了条件がないProjectは存在しないのと同じ。スコープ外がないとスコープが膨らんでCloseできない。
ProjectのAssigneeは、そのProjectの完了判断責任者とする。

### イシュー作成基準
- 細々とした依頼 → 単独のイシューとして作成
- Bug Bounty、Wizアラートなど頻出系 → ゴールなしの恒常プロジェクトにまとめる（例外）
  - 恒常Projectには週1でコメントを残す: 今週消費したpt、押し出された作業

### Claude Codeでのissue作成時の必須項目

Linearでissueを作成する際は、以下の項目を必ず設定する：

| 項目 | 設定値 | 備考 |
|------|--------|------|
| Team | `Platform` | Linearでのチーム名（PFチーム） |
| Assignee | `me`（自分） | 指定がなければ自分をアサイン |
| Estimate | ポイント見積もり | 下記の基準に従う |
| Cycle | 指定なし | 計画時に設定、割り込みは発生時点のcurrent Cycleを指定 |
| State | `Todo` | 初期状態（Triageではなく） |
| Project | 関連プロジェクト | 該当するものがあれば設定 |

Descriptionに「Why 2行」を書く（特にClaude Code生成時）：
- なぜ今やるか
- 何を防ぐか

Estimateの目安：
- 対応完了済み（記録目的）: 1 pt
- 軽微な作業: 1-2 pt
- 通常の作業: 2-4 pt
- 大きめの作業: 4-8 pt

### 割り込みIssue

割り込み対応は別Issueにする。その際、影響先を必ず明記：

```
Impact: [止めたProject名] の Issue #xxx を後ろ倒し
```

影響を言語化しないと、割り込みが「見えない負債」になる。

## 各サイクルでの動き

### 週次フロー
1. 各自: 今週のタスクを整理、ポイントづけ（他のタイミングで行えるなら任意参加）
2. 金曜日 60分の定例:
   - 前半30分: Project軸の振り返り（下記参照）
   - 後半30分: 来週やること共有、質問

### Cycle Review（前半30分）

見る対象はProjectだけ。Issueの消化数は原則見ない。

確認項目：
- 今週Closeまたは前進したProject
- 止まったProject
- 止まった理由（割り込み / 見積ミス / 依存）
- 今週、意図的にやらなかったこと（1つ）

最後の「やらない判断」が意思決定ログの核。
例: X ProjectのIssue #123は、Yを優先するため次Cycleへ送った

### 定例参加メンバー
- PFチーム + その週にPFタスクで稼働する兼務メンバー

### タスク割り振り
- プロジェクト以外の細々とした依頼 → PFころ + 挙手で割り振り
- チケット切ってアサインしていく

### 目指す状態
今週やることはLinearのactive cycleを見ればわかる状態

## ポイント見積もり

| 基準 | 目安 |
|---|---|
| 1週間の作業量 | 8 pt |
| 1営業日の作業量 | 2 pt |

- 兼務などで稼働が少ない週は上限をよしなに調整
- 工数はブレる想定なので、取り組む前の体感で決めてOK

## Linear MCP API の注意点

サイクルやチームの指定には、名前やキーワードではなくIDを使う。

### サイクル操作の手順
1. `list_cycles(teamId, type="current")` でサイクルIDを取得
2. `list_issues` でサイクル指定する場合は、取得したIDを使う（`current` 等の文字列は効かない）
3. issueのサイクル移動も同様にIDを直接指定（`next` 等の文字列は効かない）

```
# 正しい手順
cycles = list_cycles(teamId="<TEAM_ID>", type="current")
cycle_id = cycles[0].id
list_issues(assignee="me", cycle=cycle_id)

# 間違い（効かない）
list_issues(assignee="me", cycle="current")
update_issue(id="PF-xxx", cycle="next")
```

### チームID
- `~/.claude/rules/service-environments.local.md` を参照

## やらないこと

運用が目的化するのを防ぐため、以下は意図的に入れない：

- 細かいステータスを増やす
- pt実績を厳密に追う
- KPIっぽい数値評価
