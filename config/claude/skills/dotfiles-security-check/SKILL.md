---
name: dotfiles-security-check
description: dotfilesリポジトリのセキュリティ監査。「dotfilesセキュリティチェック」「security check」「セキュリティ監査」「シークレットスキャン」等で起動。
user-invocable: true
allowed-tools:
  - Bash(git ls-files:*)
  - Bash(git diff:*)
  - Bash(grep:*)
  - Bash(pnpm config:*)
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
pnpm config get ignore-scripts        # → true
pnpm config get min-release-age       # → 3以上
grep minimum-release-age ~/.npmrc     # → 4320以上（pnpmも.npmrcを読む）
grep strict-peer-dependencies ~/.npmrc # → true
grep exclude-newer ~/.config/uv/uv.toml  # → 設定あり
```

### 6. install.sh の安全性

`curl | bash` パターンや `chmod 777` がないか確認。

### 7. private情報の混入チェック

`~/.claude/CLAUDE.md` のセキュリティセクションで「publicリポに含めない」と定めている情報がgit tracked ファイルに混入していないか確認する。検出した場合は `dotfiles-private` 配下の `*.local.md` に移す。

#### 検出パターン

```bash
# 7-1. 個人・会社ドメインのメールアドレス
git ls-files | xargs grep -nE '[a-zA-Z0-9._%+-]+@(cyberagent|winticket|cloud-identity|perman)\.[a-zA-Z.]+' 2>/dev/null

# 7-2. GCPプロジェクトID（WinTicket org）
git ls-files | xargs grep -nE '\b(billioon-[a-zA-Z0-9-]+|winticket-[a-zA-Z0-9-]+)\b' 2>/dev/null

# 7-3. 社内ナレッジ・チケット系のホスト
git ls-files | xargs grep -nE '[a-zA-Z0-9-]+\.(kibe\.la|cybozu\.com|atlassian\.net|backlog\.com)' 2>/dev/null

# 7-4. SlackチャンネルID（C + 10桁前後の英数）/ Slack permalink
git ls-files | xargs grep -nE '\b[CG][A-Z0-9]{8,11}\b|[a-z0-9-]+\.slack\.com/archives/' 2>/dev/null

# 7-5. AWSアカウントID（12桁数字）/ ロールARN
git ls-files | xargs grep -nE 'arn:aws:[a-z0-9-]+::[0-9]{12}:|\b[0-9]{12}\b.*(account|role|aws)' 2>/dev/null

# 7-6. 内部URL・社内ドメイン
git ls-files | xargs grep -nE 'https?://[a-zA-Z0-9.-]+\.(internal|local|corp|cyberagent\.co\.jp|winticket\.co\.jp)' 2>/dev/null

# 7-7. Datadog等のメトリクス名（サービス固有）
git ls-files | xargs grep -nE '\b(trace|metric|service)\.name[:=]\s*["\x27]?(winticket|billioon)' 2>/dev/null
```

#### 検出時の対応

1. publicリポに残してよいか判断する。基準:
   - 個人特定情報・組織特定情報を含む → private に移す
   - 一般的な手順説明の例示で、誰の環境でも通用する → public でよい（メアドは `user@example.com` 等に置換）
2. private に移す場合の配置先:
   - `~/.claude/CLAUDE.md` 系の rules → `~/gh/github.com/ryosukesuto/dotfiles-private/config/claude/rules/<topic>.local.md`
   - skill 固有 → `<skill-dir>/SKILL.local.md`（skillファイルから `${CLAUDE_SKILL_DIR}/SKILL.local.md` で参照）
3. 既にgit履歴に残っている場合は `git filter-repo` で除去する（`git rm` だけでは履歴から消えない）:
   ```bash
   git filter-repo --replace-text <(echo 'sensitive-string==>REDACTED') --force
   ```
4. private リポは `install.sh` がシンボリックリンクで配置するので、移動後にインストールし直す必要は通常ない（既存リンク維持）

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

### 項目7（private情報）の誤検知パターン

以下は「検出されてもpublicに残してよい」ケース。除外判断の参考にする。

- `~/dotfiles-private/config/...` のようなパス参照: ディレクトリ構造の説明で、機密情報そのものではない
- `user@example.com` `someone@cyberagent.co.jp` 等の例示: コマンド例示の placeholder。ただし実在のメアドが混入していないか個別確認
- 「Kibela」「Slack」等のサービス名のみの言及: ID/URL/チャンネル名を含まなければ問題なし
- `winticket-org` `WinTicket org` 等の組織名のみの一般的な記述: org名はOSSリポにも露出しているため許容（ただしプロジェクトIDは別）
- Renovate設定の `commitMessagePrefix: "chore(deps):"` 等の汎用設定値: org固有でない

### 重要度の判定基準

| 重要度 | 例 |
|--------|-----|
| High | AWSアカウントID（12桁）、GCPプロジェクトID、SlackチャンネルID、内部URL（社内のみアクセス可能なホスト） |
| Medium | 個人/同僚のメールアドレス、メトリクス名、Datadogダッシュボード名 |
| Low | org名のみの言及、サービス名のみの言及（IDなし） |
