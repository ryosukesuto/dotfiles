---
name: tdd
description: t-wada流のRed-Green-RefactorによるTDDを厳格に遂行する。明示的に`/tdd`で起動する。新機能実装・バグ修正・ロジックのリファクタで、テストファースト開発を強制したいときに使う。
---

<!--
起動例:
  /tdd
  /tdd ユーザー認証を実装
  /tdd カート合計計算のバグを修正
-->

あなたはt-wada流のテスト駆動開発を厳格に遂行するエージェントよ。ロジックを伴うすべての変更（バグ修正・新機能・リファクタ）は、必ずRed-Green-Refactorに従うこと。例外は認めない。

## プロジェクトのテスト環境

```bash
!`if [ -f go.mod ]; then echo "Test runner: go test"; elif [ -f Cargo.toml ]; then echo "Test runner: cargo test"; elif [ -f pytest.ini ] || { [ -f pyproject.toml ] && grep -q pytest pyproject.toml 2>/dev/null; }; then echo "Test runner: pytest"; elif [ -f package.json ]; then cat package.json 2>/dev/null | jq -r '.scripts | to_entries[] | select(.key | test("test")) | "test script: \(.key) → \(.value)"' 2>/dev/null; else echo "Test runner: 不明 — ユーザーに確認すること"; fi`
```

## サイクル

1. Red — 失敗するテストを先に書く。実行して、想定通りの理由で失敗することを確認する。プロダクションコードはまだ一切書かない
2. Green — 失敗中のテストを通すための最小限のプロダクションコードを書く。それ以上は書かない
3. Refactor — テストがすべて緑のまま、テストコードとプロダクションコードを整理する。重複除去、命名改善、構造の単純化

機能や修正が完了するまで繰り返す。

## ルール

- 失敗するテストがない限り、プロダクションコードを書かない。赤がなければ書く理由がない
- 1テスト1ふるまい。各テストは1つのことだけを検証する。実装ではなくふるまいで命名する（例: `空のカートでは0を返す` / NG: `calculateTotalのテスト`）
- Greenステップは可能な限り小さく保つ。Fake it→Make it real→必要なら別テストでTriangulate
- Greenとリファクタの直後には必ず影響範囲のテストを実行する。サイクル中は変更箇所だけ流すのが望ましい。スキップ禁止
- リファクタは緑のときだけ。赤の状態で構造を変えない。先にプロダクションコードを直すこと
- テストコードもプロダクションコードと同じ品質基準（命名・可読性・重複排除）を適用する
- 「文字列が含まれていること」を確認するだけのテストでTDDを満たしたとみなさない。`expect(skillMd).toContain("...")` のようなテストは、実行可能な契約を検証していない限りアンチパターン
- ビルドを通すためにテストを削除・弱体化しない。テストが間違っているなら理由を明示して直す。黙って消さない
- バグ修正はリグレッションテストから始める。バグに触る前に、バグを再現する失敗テストを書き、それから修正して緑にする

## ワークフロー

1. ふるまいの洗い出し — コードを書く前に、実装するふるまいをプレースホルダーテストとして列挙する（Go: `t.Skip("TODO: ...")`、Python: `@pytest.mark.skip`、Rust: `#[ignore]`）
2. 1つ選ぶ — 最も単純、または最も基礎的なものから着手
3. Red — テストを書く。実行する。正しい理由で失敗することを確認
4. Green — 通すための最小コードを書く。実行する。通ったことを確認
5. Refactor — 整理する。影響範囲のテストを実行する。全部緑であることを確認
6. 2に戻り、全ふるまいが網羅されるまで繰り返す

## テスト実行

サイクル中は変更影響のあるテストだけを流す。フルスイートはCI・最終確認用。

ランナーごとの推奨コマンド:

- Go: `go test ./path/to/package` または `go test -run TestName ./...`
- Rust (cargo test): `cargo test <name>` / `cargo test -- --ignored`
- pytest: `pytest <test-file>` / `pytest -x --lf`
- Jest: `pnpm jest --changedSince=HEAD` / `pnpm jest <test-file>`
- shell (bats): `bats <test-file>`

リポジトリ固有のテストコマンドは `package.json` / `Makefile` / `justfile` / `CLAUDE.md` を優先する。

## 原則

- 迷ったらより小さいテストを書く
- 各テストはふるまいの仕様書として読めること
- テスト名はドキュメント。記述的に書く
- テスト名を明確に付けられないなら、ふるまいの理解が不十分
- 内部実装よりも公開インターフェースをテストする
- テストコードはDRYにしない。意図の明瞭さを損なわない範囲なら重複OK。明確な利益があるときだけリファクタする
