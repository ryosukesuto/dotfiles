# クロスリポジトリ整合性ルール

server の変更が server-config / ops に影響するケースのチェックリスト。

## server -> server-config 連動

### コマンドライン引数（Cobra flags）

server で Cobra flag を追加・変更・削除した場合:

- `[P1]` server-config の `config/{service}/server/{env}/values.yaml` の `args` セクションに対応する変更が必要
- `[P0]` flag を削除した場合、server-config 側に古い値が残っていると `unknown flag` で起動不能になる
- flag のデフォルト値変更は、server-config 側で明示的に値を指定していない環境に影響する

確認方法:
```bash
# server-config リポジトリで該当フラグを検索
grep -r "flag-name" ../server-config/config/
```

### gRPC サービス定義の変更

proto ファイルの変更がある場合:

- `[P0]` フィールド番号の変更・削除は破壊的変更
- `[P1]` 新規 RPC メソッドの追加は、server-config 側の RBAC 設定に影響する可能性
- `[P1]` レスポンス型の変更は Gateway 側の変換ロジックに影響

### 新規マイクロサービスの追加

- `[P1]` server-config に Helm values / ApplicationSet / PipeCD 設定が必要
- `[P1]` ops に ServiceAccount / IAM / Secret Manager 設定が必要

## server -> ops 連動

### Spanner テーブル / カラム

server で新しいテーブルやカラムを前提としたコードがある場合:

- `[P0]` ops リポジトリの Spanner DDL にテーブル/カラム定義が追加されているか
- `[P1]` マイグレーション順序: DDL 変更が先にデプロイされる必要がある

確認方法:
```bash
# ops リポジトリで該当テーブルを検索
grep -r "TableName" ../ops/terraform/gcp/server/spanner/
```

### Secret Manager

server で新しい Secret を参照するコードがある場合:

- `[P1]` ops の Secret Manager に対応するシークレットが全環境で作成されているか
- `[P1]` ServiceAccount に `secretmanager.versions.access` 権限があるか

### Pub/Sub トピック / サブスクリプション

server で新しい Pub/Sub トピックを使用する場合:

- `[P1]` ops に Pub/Sub リソース定義が追加されているか
- `[P1]` デッドレターキュー / リトライポリシーが設定されているか
- `[P2]` IAM バインディング（publish / subscribe 権限）が適切か

## 影響判定フローチャート

PRの差分に以下が含まれるかチェック:

1. `flag.String` / `flag.Int` / `cobra.Command` の追加・変更・削除 -> server-config 確認
2. `proto/` 配下の変更 -> Gateway 変換ロジック + クライアント影響確認
3. `database/spanner/` に新テーブル参照 -> ops DDL 確認
4. `secretmanager` パッケージの呼び出し追加 -> ops Secret 確認
5. `pubsub` パッケージの新トピック -> ops Pub/Sub 確認
6. `ServiceAccount` / `WorkloadIdentity` 関連 -> ops IAM 確認

## PR Description への記載推奨

クロスリポジトリ影響がある場合、PR Description に以下を記載するよう提案:

```markdown
## クロスリポジトリ影響
- [ ] server-config: {変更内容と対応PR}
- [ ] ops: {変更内容と対応PR}
- [ ] デプロイ順序: {ops -> server / server -> server-config 等}
```
