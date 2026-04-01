---
name: dotfiles-security-check
description: dotfilesリポジトリのセキュリティ監査。「dotfilesセキュリティチェック」「security check」「セキュリティ監査」「シークレットスキャン」等で起動。
user-invocable: true
allowed-tools:
  - Bash(git ls-files:*)
  - Bash(git diff:*)
  - Bash(grep:*)
  - Bash(npm config:*)
  - Read
  - Grep
  - Glob
---

# /dotfiles-security-check

dotfilesリポジトリのセキュリティ監査を実行する。publicリポジトリに機密情報が混入していないか、セキュリティ設定が適切かを包括的にチェックする。

## 実行手順

### 1. シークレット検出（git tracked ファイル）

gitで管理されているファイルから機密情報パターンを検出する。pre-commit hookでも検査しているが、既存ファイルの全量チェックはこのSkillで行う。

```bash
git ls-files | xargs grep -nE \
  'AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|xoxb-[0-9]+-[a-zA-Z0-9]+|password\s*[:=]\s*["\x27][^"\x27]{8,}|AIza[0-9A-Za-z_-]{35}' \
  2>/dev/null
```

### 2. .gitignore カバレッジ

機密ファイルが除外されていることを確認する。漏れがあるとgit add時に事故が起きる。

確認対象: `*.local`, `*.local.*`, `*.pem`, `*.key`, `*.p12`, `.env`, `.env.*`, `aws/credentials`, `.zsh_history`, `.bash_history`

### 3. SSH config セキュリティ

MITM攻撃やSSHキー漏洩を防ぐため、以下を確認:
- `StrictHostKeyChecking no` がリモートホストに設定されていないか（ローカルのみ許容）
- `ForwardAgent yes` が不要なホストに設定されていないか
- 参照されている秘密鍵パスが実在するか

### 4. settings.json の権限設定

Claude Codeの権限設定が適切かを確認。deny ルールの漏れはサプライチェーン攻撃のリスクになる。
- deny に主要な危険コマンドが含まれているか
- allow に過度に広いパターンがないか（`Bash(curl:*)`, `Bash(wget:*)` 等）

### 5. サプライチェーン対策

パッケージマネージャのセキュリティ設定が有効かを確認する。axios事件（2026/3）のような攻撃を防ぐ。

```bash
npm config get ignore-scripts        # → true
npm config get min-release-age        # → 3以上
grep minimum-release-age ~/.npmrc     # → 4320以上
grep exclude-newer ~/.config/uv/uv.toml  # → 設定あり
```

### 6. install.sh の安全性

`curl | bash` パターンや `chmod 777` がないか確認。

### 7. 環境変数のハードコード

git tracked ファイルにプロジェクトID、アカウントID、内部URL、メールアドレス等が含まれていないか確認。

## 出力形式

```
## dotfiles セキュリティチェック結果

実行日: YYYY-MM-DD

### 検出された問題
| # | 重要度 | ファイル:行 | 内容 |
|---|--------|-----------|------|

### 確認済み（問題なし）
- ✓ .gitignore カバレッジ
- ✓ SSH config
- ...

### 前回からの変更点
- （前回チェック結果との差分があれば記載）
```

## 実行後

結果をデイリーノートに記録:
```bash
echo "- $(date '+%Y/%m/%d %H:%M:%S'): dotfiles セキュリティチェック実施" >> ~/gh/github.com/ryosukesuto/obsidian-notes/$(date '+%Y-%m-%d')_daily.md
```

## Gotchas

- シークレット検出のgrepパターンはSSH configのHost定義やコメント内の例示にも反応することがある。誤検知は内容を確認してからスキップ
- `*.local` ファイルはgitignoreで除外されているため、git ls-filesには含まれない。local ファイル内のシークレットチェックはこのSkillの対象外
- settings.json の deny ルールは `--dangerously-skip-permissions` でも有効。ただし ask ルールはスキップされる点に注意
