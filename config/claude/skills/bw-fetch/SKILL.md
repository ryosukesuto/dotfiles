---
name: bw-fetch
description: Bitwarden から credential を取得して環境変数に export するスキル。1Password 経由の非対話 unlock (`bin/bw-unlock`) も含むので、`bw unlock` をユーザーに手動実行させない。Datadog API、Slack token などサービス毎の preset を `presets.local.md` で管理し、`eval "$(bw-fetch <preset>)"` で env に注入する。「BW_SESSION」「Bitwarden」「unlock」「DD_API_KEY」「認証情報取得」「credential 取得」等で起動。
---

# bw-fetch

Bitwarden 経由で credential を取得し、`eval` 前提の `export` 文を stdout に出すスキル。`~/.zshrc.local` 内の `bw-unlock` 関数も実体は本スキルの `bin/bw-unlock` を呼ぶ薄い wrapper にして DRY を保つ。

## なぜスキルにするか

- Bitwarden の master password 入力は `op read` 経由で 1Password に委譲するため、Claude Code の Bash ツールから対話的 readline を通さずに非対話で実行できる
- BW_SESSION / 取得した値の transcript 露出を `eval` 前提のフローで防ぐ（値を直接 echo しない）
- `presets.local.md` (dotfiles-private 配下) に item id を集約して、他コマンドからは preset 名のみで呼べる

## 使い方

### プリセット呼び出し

```bash
eval "$(~/.claude/skills/bw-fetch/bin/bw-fetch dd)"
echo "DD_API_KEY length=${#DD_API_KEY}"   # 長さのみ確認
```

### アドホック呼び出し

```bash
eval "$(~/.claude/skills/bw-fetch/bin/bw-fetch --item <bw_item_id> --field api_key --as MY_KEY)"
```

### unlock のみ

```bash
export BW_SESSION="$(~/.claude/skills/bw-fetch/bin/bw-unlock)"
```

## 動作

1. 最初の呼び出しで `op read 'op://Personal/Bitwarden/password'` から master password を取得し `bw unlock --raw --passwordenv` でセッション発行
2. 既に有効な BW_SESSION があれば再 unlock しない（`bw status` で `unlocked` を確認）
3. preset / アドホック指定された field を `bw get item` で取り出し、`printf 'export %s=%q\n' "$VAR" "$VAL"` 形式で stdout に出す
4. 呼び出し側は `eval "$(...)"` で受け取る前提

## 値を露出させないルール

- `bw-fetch` は **必ず `eval` 経由で呼ぶ**。直接実行すると export 文（値含む）が stdout に出て transcript に残る
- 取得後の確認は `${#VAR}` で長さのみ。`echo "$VAR"` は禁止
- セッション破棄: `unset BW_SESSION && bw lock`

## ファイル構成

```
bw-fetch/
├── SKILL.md             (本ファイル)
├── bin/
│   ├── bw-unlock        # BW_SESSION を stdout に。eval 前提
│   └── bw-fetch         # preset / --item で credential を export
└── presets.local.md     # dotfiles-private 配下への symlink。preset 表
```

## プリセットの追加

`dotfiles-private/config/claude/skills/bw-fetch/presets.local.md` の表に行を追加する。同じ preset 名で複数行書けば、まとめて複数の env var が export される。

## 関連

- `~/.zshrc.local` の `bw-unlock` 関数は本スキルの `bin/bw-unlock` を呼ぶ wrapper
- 1Password CLI (`op`) が事前にログイン済みである必要がある（macOS の場合 touchID で解錠）
