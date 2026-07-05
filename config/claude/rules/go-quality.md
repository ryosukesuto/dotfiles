---
paths:
  - "**/*.go"
---

# Go コード品質ルール

`.go` を書く/レビューするときに守る最低限のガイドライン。Effective Go と Google Go Style Best Practices から、実害につながりやすいものを抜粋している。

## gofmt 必須

`gofmt` の出力と一致しないコードはマージ禁止。エディタの保存時 format で常に揃える。ローカルでは PostToolUse hook (`bin/claude-go-after-edit`) が違反時に `exit 2` で Claude に修正を促す。

```bash
gofmt -d file.go   # 差分表示
gofmt -w file.go   # 上書き整形
```

## 命名規則

| 対象 | 規則 | 例 |
|---|---|---|
| エクスポート | `UpperCamelCase` | `ParseConfig` |
| パッケージ内部 | `lowerCamelCase` | `parseInternal` |
| パッケージ名 | 短く小文字、`_` / `camel` 禁止 | `httputil`, `auth` |
| 略語 (URL, ID, HTTP) | 全大文字統一 | `userID`, `parseURL`, `httpClient` |
| インターフェース | 動詞+er を推奨 | `Reader`, `Closer` |

`Get` プレフィクスは getter に付けない (`user.Name()` が正、`user.GetName()` は冗長)。

## エラー処理

- `if err != nil { return ... }` を省略しない。`_ = err` で握り潰さない
- 文脈を足すときは `fmt.Errorf("foo: %w", err)` で wrap する。`%v` ではなく `%w` を使うと `errors.Is` / `errors.As` で扱える
- sentinel error は `var ErrFoo = errors.New("foo")` で公開
- ライブラリでは `panic` を投げない。`recover` で握り潰さない (main 直下と意図した境界のみ)

## レシーバ

- メソッド集合に書き換えがある or 大きい構造体 → ポインタレシーバ
- 小さい (24 バイト程度以下) かつ immutable → 値レシーバ
- 同じ型のレシーバはポインタ/値を混在させない (一貫性優先)

## インターフェース

- consumer 側に定義する (利用するパッケージ側)
- 戻り値はコンクリート型、引数はインターフェース型 ("Accept interfaces, return structs")
- 小さく保つ (1-3 メソッド)。`io.Reader` / `io.Writer` がお手本

## ドキュメントコメント

エクスポートされた全 identifier に godoc コメントを書く。識別子名で始める。

```go
// ParseConfig reads r and returns the parsed configuration.
// It returns an error if r contains invalid syntax.
func ParseConfig(r io.Reader) (*Config, error) {
```

## golangci-lint 必須

ローカルでも CI でも `golangci-lint run` を通す。

- 既定で有効: `govet`, `errcheck`, `staticcheck`, `unused`, `ineffassign`
- PostToolUse hook では golangci-lint の結果を stderr 表示するが `exit 2` は出さない (プロジェクトの `.golangci.yml` 依存のため、blocking は CI に任せる)

## よくある指摘の回避パターン

### errcheck: unchecked error

```go
// Bad: defer の close エラーが消える
defer file.Close()

// Good: 名前付き戻り値 + errors.Join で集約
defer func() {
  if cerr := file.Close(); cerr != nil {
    err = errors.Join(err, cerr)
  }
}()
```

### govet: printf format mismatch

```go
// Bad: 引数不足
fmt.Errorf("got %v want %v", got)

// Good
fmt.Errorf("got %v want %v", got, want)
```

### staticcheck: unused result (SA4006)

```go
// Bad: 戻り値破棄。strings は immutable なので元の s は変わらない
strings.Replace(s, "a", "b", -1)

// Good
s = strings.ReplaceAll(s, "a", "b")
```

### gosimple: 冗長な比較

```go
// Bad
if x == true { ... }
if len(s) > 0 { ... }   // 文字列なら s != "" の方が意図が明確

// Good
if x { ... }
if s != "" { ... }
```

## 安全性

- `os/exec` で外部入力をシェル展開しない (`exec.Command(name, arg...)` で配列指定)
- HTTP body は `defer resp.Body.Close()` を必ず付ける
- ゴルーチンの後始末: `context.Context` で cancel 伝播、`sync.WaitGroup` で待機
- ファイル権限: 機密ファイル作成は `0o600` (リテラルプレフィクス `0o` で意図を明示)
- `crypto/rand` を使う。`math/rand` は暗号用途禁止

## 例外と判断軸

- 既存コードの命名違反は専用 PR でまとめて直す。新規追加分のみ守る (混在 PR でレビュー負荷を上げない)
- `//nolint:linter // 理由` で suppress するときは必ず理由をコメントに残す
- 短いユーティリティ (10 行以下) で自明な部分は doc コメント省略可

## 関連

- shell の同等ルール: `~/.claude/rules/shell-quality.md`
- terraform の同等ルール: `~/.claude/rules/terraform-quality.md`
- Effective Go: https://go.dev/doc/effective_go
- Google Go Style Best Practices: https://google.github.io/styleguide/go/best-practices.html
