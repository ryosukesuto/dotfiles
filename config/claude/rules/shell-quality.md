# Shell スクリプト品質ルール

`.sh` を書くとき / レビューするときに守る最低限のガイドライン。Google Shell Style Guide と sharats.me/posts/shell-script-best-practices の定番チェック項目から、実害につながりやすいものを抜粋している。

## 必須ヘッダ

スクリプト先頭は以下を 3 行セットで固定する。

```bash
#!/usr/bin/env bash
set -euo pipefail
# sort / uniq の locale 依存を排除
export LC_ALL=C
```

- `set -euo pipefail`: 失敗時に早期停止 (`-e`)、未定義変数で停止 (`-u`)、パイプ途中失敗を伝播 (`-o pipefail`)
- `LC_ALL=C`: `sort` / `uniq` / 正規表現の locale 依存で結果が環境ごとに変わる罠を防ぐ。`comm` の動作も安定する

## 構文 / スタイル

| 項目 | 推奨 | 避ける |
|---|---|---|
| 条件式 | `[[ ]]` | `[ ]` (sh 互換が要らないなら) |
| コマンド置換 | `$(...)` | `` `...` `` |
| 関数名 | `lower_snake_case` | `camelCase` / `kebab-case` |
| 環境変数 / 定数 | `UPPER_SNAKE_CASE` | 大文字小文字混在 |
| 関数内変数 | `local foo; foo=$(...)` | `local foo=$(...)` (`$()` の exit status が失われる) |
| 一時ディレクトリ | `mktemp -d` + `trap 'rm -rf "$T" EXIT'` | 固定パス `/tmp/...` |
| ループ内変数を保持 | `while ... done < <(...)` | `... \| while ...` (サブシェルで変数が消える) |
| glob no-match 対処 | `[[ -f "$f" ]] || continue` または `shopt -s nullglob` | 何もしない (no-match で literal `*.json` がループ変数に入る) |
| 読み込み | `read -r` | `read` (バックスラッシュエスケープが暴れる) |

## shellcheck 必須

ローカルでも CI でも shellcheck を通す。

- 推奨 severity: `--severity=info`
  - error / warning / info を表示。style 指摘 (SC2001 / SC2129 等) は除外
- CI: `validate-workflows.yml` 系で `.github/scripts/*.sh` を検査
- ローカル: PostToolUse hook (`bin/claude-shellcheck-after-edit`) で Edit/Write 後に自動実行
  - info/warning は stderr 表示のみ (exit 0)。transcript で人間が確認するノイズ層
  - error 重大度の findings がある場合のみ exit 2 で Claude のコンテキストに注入し、自己修正を促す
  - 二段構えにする理由: 既存 .sh に info 寄り style 指摘が混在するため、全件 blocking にすると Claude が無関係な修正に脱線する

## よくある style 指摘の回避パターン

### SC2001 (echo \| sed の置換)

```bash
# Bad
echo "$lines" | sed 's/^/  - /'

# Good 1: while loop
while IFS= read -r line; do
  printf '  - %s\n' "$line"
done <<< "$lines"

# Good 2: パラメータ展開 (単一値かつ簡単な置換のみ)
printf '%s\n' "${lines/foo/bar}"
```

### SC2129 (個別 redirect の集約)

```bash
# Bad
echo "key1=val1" >> "$FILE"
echo "key2=val2" >> "$FILE"
echo "key3=val3" >> "$FILE"

# Good
{
  printf 'key1=%s\n' "$val1"
  printf 'key2=%s\n' "$val2"
  printf 'key3=%s\n' "$val3"
} >> "$FILE"
```

### SC2086 (unquoted variable)

```bash
# Bad
rm $file

# Good
rm "$file"
```

スペースや glob 文字を含むパスで事故る。整数比較 (`[[ "$n" -gt 0 ]]`) でも quote 推奨。

## 安全性

- `eval` を使わない。動的なコマンド生成は配列展開 (`"${cmd[@]}"`) で置換する
- 信頼できない入力 (CLI 引数、API レスポンス、ファイル内容) を直接シェル展開しない
- `set -x` でデバッグするときは秘密値を出力していないか確認

## 例外と判断軸

- 既存スクリプトに残っている SC2001 / SC2129 を直すかは「単独で直すと一貫性が崩れる」なら一括 PR にまとめる
- shellcheck の suppress comment (`# shellcheck disable=SC2001`) は意図がある場合のみ。理由をコメントに残す
- 1 ファイルで完結する短いスクリプト (10 行以下) なら一部省略可。それでも shebang / `set -euo pipefail` は必須

## 関連

- `~/.claude/rules/heredoc-escaping.md`: クォート付き heredoc のエスケープ規約
- shellcheck wiki: 各ルールの詳細は https://www.shellcheck.net/wiki/SCxxxx で参照可能
