---
name: check-payoff
description: 指定レースの払戻状態を Spanner (ReportVenueRaces + BettingTickets) で確認し、完了/バッチ未起動/電文未達/未開催を判定する。未完了の場合は復旧手順を提示する。CS対応・障害対応で「このレース払戻できてる？」に即答するためのスキル。
user-invocable: true
argument-hint: "<RaceId> [--env=prd|stg|dev] [--sport=keirin|autorace]"
allowed-tools:
  - Bash(gcloud spanner databases execute-sql:*)
  - Bash(gcloud config list)
  - Bash(gcloud auth list)
  - Bash(gcloud config configurations activate:*)
  - Bash(date:*)
  - Read
  - Grep
  - Glob
---

# レース払戻状態確認スキル

特定レースの払戻が完了しているかを Spanner 直読で確認する。WinTicket/server リポジトリ配下で動作することを前提とする。

## 前提

環境固有のパラメータ（GCP project / instance、gcloud config、実行例、NEXT-VIS 管理画面の経路）は `${CLAUDE_SKILL_DIR}/SKILL.local.md` を参照する。このファイル本体には project ID や instance 名をハードコードしない。

## 適用トリガー

- 「このレース払戻できてる？」「xx場yR 完了してる？」等の問い合わせ
- Slack で `RaceId` が飛んできて状態確認が必要なとき
- 障害対応後の取りこぼし確認
- CS からの「お客様が払戻を受け取れていない」報告の一次切り分け

## 入力

- `RaceId`（必須）: 12桁の文字列。`{RaceNumber:02d}{VenueNumber:02d}{YYYYMMDD}` フォーマット
  - 日付部分は **レース当日**（cupid の開催初日ではない点に注意）
- `--env`（省略可、既定 `prd`）: `prd` / `stg` / `dev`
- `--sport`（省略可）: `keirin` / `autorace`。省略時は VenueNumber から自動判定（衝突時は必須）

### RaceId の取得方法

1. WINTICKET のレース詳細ページで bookmarklet を実行（最速）— スクリプトは `SKILL.local.md` 参照
2. Slack / Datadog のエラーログからコピー
3. 管理画面 URL の `?race=...` パラメータ
4. Spanner で日付指定して逆引き

逆引きクエリ（keirin / autorace DB 共通）:

```sql
SELECT
  VenueNumber, RaceNumber, Date,
  CONCAT(
    LPAD(CAST(RaceNumber AS STRING), 2, '0'),
    LPAD(CAST(VenueNumber AS STRING), 2, '0'),
    Date
  ) AS RaceId
FROM ReportVenueRaces
WHERE Date = "YYYYMMDD"
ORDER BY VenueNumber, RaceNumber;
```

## 実行フロー

### Phase 1: RaceId を分解する

`RaceId` (12桁) を以下に分解:

```
{RaceNumber:02d}{VenueNumber:02d}{YYYYMMDD}
```

### Phase 2: Sport を判定する

`--sport` が指定されていればそれを使う。されていなければ VenueNumber で推定する。

| VenueNumber 範囲 | Sport | 参照ファイル |
|---|---|---|
| 1-6 | autorace | `pkg/venue/autorace.go` |
| 11 以上 | keirin | `pkg/venue/keirin.go` |
| 12 | **衝突**（autorace=川口2回目 / keirin=青森） | `--sport` 必須 |

実装: `pkg/venue/autorace.go` と `pkg/venue/keirin.go` の VenueNumber マップを両方 Read し、autorace_set と keirin_set の交差に属する VenueNumber は `--sport` 必須扱いにする。交差外で判定が曖昧なケースは、broker DB で `BettingTickets WHERE RaceId = ? LIMIT 1` を SportId 別に試し、ヒットした側を採用する（2回クエリを避けるため、先に SportId を確定する）。

Sport → SportId 対応（`proto/sport/code.pb.go`）:

| Sport | SportId |
|---|---|
| keirin | 0 |
| autorace | 1 |
| keirin_multirace | 2 |
| keiba | 3 |

**本スキルの対応範囲は keirin / autorace のみ**。multirace / keiba は別スキル（または未対応）。

### Phase 3: ReportVenueRaces で電文・払戻状態を確認する

sport に応じて database を選択（keirin → `keirin` DB、autorace → `autorace` DB）。

```sql
SELECT
  VenueNumber,
  RaceNumber,
  Date,
  ReportedAt,
  FinalReportedAt,
  RepaidAt,
  FixedAt
FROM ReportVenueRaces
WHERE Date = "<YYYYMMDD>"
  AND VenueNumber = <VenueNumber>
  AND RaceNumber = <RaceNumber>;
```

gcloud CLI 実行例は `SKILL.local.md` 参照。

### Phase 4: BettingTickets で Done 集計

broker DB で:

```sql
SELECT Done, COUNT(*) AS cnt
FROM BettingTickets@{FORCE_INDEX=BettingTicketsBySportIdRaceIdCreatedAtDesc}
WHERE SportId = <SportId>
  AND RaceId = "<RaceId>"
GROUP BY Done;
```

### Phase 5: 判定

Phase 3 と Phase 4 の結果に加えて、レース終了時刻経過有無（`FixedAt` と現在時刻の比較）を組み合わせて分類する。

| パターン | Phase 3 | Phase 4 | 終了時刻 | 判定 | 対応 |
|---|---|---|---|---|---|
| A | `RepaidAt > 0` | `Done=true` のみ | - | 完了 | 対応不要 |
| B | `FinalReportedAt > 0 AND RepaidAt = 0` | `Done=false` 残あり | 経過 | バッチ未起動 | `SettleBettingTickets` の再トリガーまたは broker-api の状態確認 |
| C | `FinalReportedAt = 0` | `Done=false` 多数 | 経過 | 電文未達 | NEXT-VIS 管理画面から電文再実行 |
| D | `RepaidAt > 0` | `Done=false` が少量残る | - | 部分未完了 | 個別 UserId で原因調査（再試行エラー等） |
| E | `FinalReportedAt = 0` | `Done=false` のみ or 少量 | 未経過 | 未開催 | レース終了待ち、対応不要 |

### Phase 6: 復旧手順の提示

#### B. バッチ未起動

- broker-api / broker-worker のログを `RaceId` でフィルタし `SettleBettingTickets` 呼び出しの有無を確認
  - broker-worker は ops リポジトリ管理外のため、Datadog で `service:broker-worker` を直接参照する
- 呼び出されていない場合は上流バッチ（analyzer 等）の再実行を検討
- 呼び出されてエラーで落ちている場合はエラー内容を共有

#### C. 電文未達

- レース終了時刻を過ぎているか確認
- 過ぎている場合は NEXT-VIS 管理画面から電文再実行（経路は `SKILL.local.md` 参照）
- 再実行後、Phase 3-4 のクエリを再実行して `Done=true` に遷移することを確認

#### D. 部分未完了

Phase 4 に Done 別内訳を追加して UserId を抽出:

```sql
SELECT UserId, Done, CreatedAt, UpdatedAt
FROM BettingTickets@{FORCE_INDEX=BettingTicketsBySportIdRaceIdCreatedAtDesc}
WHERE SportId = <SportId>
  AND RaceId = "<RaceId>"
  AND Done = false
LIMIT 100;
```

個別 UserId で Wallet / Receipt の状態確認（`fix-wallet-receipt-diff` スキル併用も検討）。

### Phase 7: 結果レポート

```
## check-payoff: <RaceId>

- Sport: <keirin/autorace> (SportId=<N>)
- Venue: <VenueNumber> (<venue_name>) R<RaceNumber> / <Date>
- Environment: <prd/stg/dev>

### ReportVenueRaces
- ReportedAt: <unix ts> (<JST>)
- FinalReportedAt: <unix ts> (<JST>)
- RepaidAt: <unix ts> (<JST>)
- FixedAt: <unix ts> (<JST>)

### BettingTickets
- Done=true: <count>
- Done=false: <count>

### 判定
<A-E のいずれか>

### 次のアクション
<Phase 6 の対応案内>
```

Unix timestamp は `date -r <ts> "+%Y-%m-%d %H:%M:%S %Z"` で JST 変換して併記する。

## 注意事項

- 本番 DB への直接クエリ。必ず `FORCE_INDEX` を付けてフルスキャンを避ける
- prd への実行は read-only クエリ（SELECT）のみ。DML（UPDATE / DELETE / INSERT）は本スキルでは実行しない
- 実行前に gcloud 認証状態を確認:
  ```bash
  gcloud config list
  gcloud auth list
  ```
  対象環境にアクセスできるアカウントに切り替わっていない場合は `gcloud config configurations activate <config名>` で切替
- 環境を誤って跨がない。`--env=prd` 指定時は project / instance が本当に本番になっているか `gcloud config list` で目視確認する

### クエリのハマりポイント

- `Date = "YYYYMMDD" AND VenueNumber IN (...) ORDER BY ...` の組み合わせで結果がゼロ件になることがある。原因は未調査だが、`Date >= "YYYYMMDD"` に書き換えると返ってくる。複数 venue を跨ぐ当日クエリでは `Date >=` を優先する

## 関連スキル

- `gen-query` — より自由度の高い調査クエリ生成
- `fix-wallet-receipt-diff` — Wallet と Receipt の差異修正（個別 UserId レベルの復旧）
- `cross-repo-investigate` — 他リポジトリ（ops / server-config）を跨ぐ調査

## 参照

- `pkg/venue/keirin.go` / `pkg/venue/autorace.go` — VenueNumber ↔ 場名
- `proto/sport/code.pb.go` — SportId enum
- `pkg/broker/api/betting_ticket.go` の `SettleBettingTickets` — 同期書き込み + 非同期通知の構造
- `../ops/spanner/keirin/dbdoc/ReportVenueRaces.md` — keirin スキーマ
- `../ops/spanner/autorace/dbdoc/ReportVenueRaces.md` — autorace スキーマ
- `../ops/spanner/broker/dbdoc/BettingTickets.md` — broker スキーマ・index定義
