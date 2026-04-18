# server リポジトリ固有レビュールール

## 1. アーキテクチャ（クリーンアーキテクチャ準拠）

### 依存方向

```
api(Interface) -> entity <- database
```

- entity は他のどの層にも依存しない
- api と database は entity に依存する
- Gateway にビジネスロジックが入り込んでいないか
- サービス間の同期的な依存の連鎖（分散モノリス）がないか
- 共有データベースによる密結合がないか

### レイヤー別の責務

| レイヤー | パッケージ | 責務 | やってはいけないこと |
|---------|-----------|------|-------------------|
| Interface | `pkg/gateway/` | REST/GraphQL変換、リクエスト検証 | ビジネスロジック |
| UseCase | `pkg/{service}/api/` | gRPCハンドラー、ビジネスルール | DB直接操作 |
| Database | `pkg/{service}/database/` | リポジトリパターンでデータアクセス抽象化 | ビジネスロジック |
| Entity | `pkg/{service}/entity/` | ドメインモデル、変換メソッド | 外部依存 |

### Entity の変換ルール

- 変換処理は Entity 構造体のメソッドとして実装する
- 別パッケージの関数として実装しない（conv, sort, filter パッケージは廃止済み）

## 2. 命名規則

| 対象 | ルール | Good | Bad |
|-----|-------|------|-----|
| 変換関数 | `New` 接頭語 | `NewUsers(users)` | `ToUsers(users)` (lint error) |
| 判定関数 | `Check` 禁止 | `IsValid(s)` | `CheckValid(s)` (lint error) |
| エラー変数 | `Err` + `{pkg}: {msg}` | `ErrNotFound = errors.New("database: not found")` | `errors.New("not found")` |
| DB操作 | Create/Update/Get/MultiGet/List/Delete | `MultiGetByScheduleIDs` | `FindByScheduleIDs` |
| スライス型 | 複数形 | `type Races []*Race` | `type RaceSlice []*Race` |
| 複数形なし | `Multi` 接頭語 | `type MultiNews []*News` | `type NewsList []*News` |

### DB操作関数の使い分け

- `Get`: ID指定の単一取得
- `MultiGet`: 複数ID指定の取得（単一キーでユニーク取得できる場合）
- `List`: 条件指定の取得（複合PKの場合も）
- `GetAll`: 全取得

## 3. エラーハンドリング

```go
// Good: コンテキスト付きラップ
return fmt.Errorf("api: failed to create digest. %w", err)

// Good: errors.Is で判定
if errors.Is(err, database.ErrNotFound) {
    return status.Error(codes.NotFound, "resource not found")
}
```

- `panic` の使用は禁止（エラーは明示的に返す）
- エラーメッセージは `{package}: {message}` 形式

## 4. 関数設計

- 引数は4つ以内。多い場合は構造体を使用
- 戻り値はスライスで返す（マップで返さない）
- 空チェックは呼び出し元でハンドリング
- ゼロ値初期化は `var` を使用（`i := 0` は Bad）

## 5. Slice / Map

```go
// Best: length 指定 + インデックス代入
ints := make([]int, 10)

// Better: capacity 指定で append
ints := make([]int, 0, 10)

// Bad: capacity 未指定
ints := make([]int, 0)
```

## 6. 並行処理

- `errgroup` + context でキャンセル制御
- goroutine の無制御な生成を避ける
- 非同期処理の終了は context で制御（Stop メソッドではなく）

## 7. Spanner 固有

### トランザクション

- ReadWriteTransaction のスコープを最小限に保つ
- 複数テーブルへの書き込み順序を統一してデッドロック回避
- 大量データの読み取りは ReadOnlyTransaction を使用

### パフォーマンス

- N+1 問題の回避: MultiGet / List を活用
- インターリーブテーブルの親子関係を意識したクエリ
- セカンダリインデックスの STORING 句の活用

## 8. Protocol Buffers

- フィールド番号の変更・削除は破壊的変更（P0）
- `make protoc` で生成ファイルが最新か確認
- バリデーションは `gogoproto.moretags` の validate タグで定義

## 9. OpenAPI アノテーション（gateway 配下のみ）

### 必須アノテーション
@Summary, @Description, @Tags, @Router, @Param, @Success, @Failure

### 命名規則

| API | パスパラメータ | クエリパラメータ |
|-----|-------------|---------------|
| v1 (User) | snake_case | snake_case |
| web (Admin) | camelCase | snake_case |

## 10. @gen アノテーション

スライス型に定型メソッドが必要な場合、@gen アノテーションの活用を推奨:

| やりたいこと | アノテーション |
|------------|--------------|
| ID→Entity の O(1) ルックアップ | `slice:map` |
| フィールド値の抽出 | `slice:extract` |
| 条件フィルタリング | `slice:filter` |
| グルーピング | `slice:group` |
| ユニーク集合 | `slice:set` |
| ソート | `slice:sort` |
| Protobuf変換 | `slice:proto` |

手動で同等のメソッドを書いている場合は `@gen` への置き換えを P3 で提案。

## 11. ログ

- メッセージは大文字開始（カスタムLinter で強制）
- `slog.Any()` は禁止（リフレクションで重い）
- 具体的な型を使用: `slog.String()`, `slog.Int64()` 等

## 12. 過去の障害・レビュー指摘から得たチェック項目

### 12.1 Spanner デッドロック

broker-server で深夜バッチ処理時に Spanner DeadLock が頻発した事例あり。
ReadWriteTransaction で複数テーブルに書き込む際、テーブル順序が呼び出し元によって異なると発生する。

### 12.2 コマンドライン引数の追加・削除

Cobra flags の追加・削除は server-config 側の values.yaml の `args` と連動する。
フラグを削除すると、server-config 側で古い値が残っている場合に起動失敗する（`unknown flag` エラー）。
`--spanner-min-opened` フラグ削除で複数 cronjob が起動不能になった事例あり。

### 12.3 Secret Manager / 外部サービス接続

Istio sidecar 経由の外部 gRPC 接続で ASM バージョン差異により 502 が発生した事例あり。
新しい外部サービス接続を追加する場合は ServiceEntry の必要性を確認。

### 12.4 Graceful Shutdown

全アプリケーションは `signal.NotifyContext` で Graceful Shutdown を実装する。
`terminationGracePeriodSeconds` > `shutdown-sleep` の関係を維持すること。
