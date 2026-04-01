# dotfiles

Claude Code / Codex CLIの設定と制御をdotfilesで管理する。

## 設計

### publicリポジトリと機密分離

dotfilesをpublicにしておくと、機密を入れられない。自然と設定の分離が進む。

機密情報は `dotfiles-private` で管理。`install.sh` がシンボリックリンクで自動配置する。publicリポジトリには `*.local.md` → `.gitignore` のパターンだけが残る。

```
dotfiles/           public: 構造とロジック
dotfiles-private/   private: 機密値
  config/claude/rules/foo.local.md  → dotfiles/ 側に symlink
```

### シンボリックリンクで即時反映

設定ファイルはコピーではなくシンボリックリンクで配置。リポジトリを編集すればそのまま反映される。`install.sh` は冪等で、何度実行しても安全。

### ghq + git worktree

リポジトリ管理は `ghq`、ブランチ作業は `git worktree` で分離。

`git checkout -b` は使わない。複数タスクを並行で進めるので、ブランチごとに独立したディレクトリが要る。AIと人間で別ブランチを同時に触れる。

```bash
ghq get github.com/org/repo          # リポジトリ取得
cd $(ghq root)/github.com/org/repo
git-wt add feature/xxx               # .worktrees/feature/xxx に作成
```

- `Ctrl+]`: ghqリポジトリをfzfで選択
- `Ctrl+\`: worktreeをfzfで選択
- mainへの直接コミットはpre-commitフックでブロック

### direnvで環境切替

AWSプロファイル、GCPプロジェクト、環境名は `direnv` で自動切替。`cd` するだけでセットされ、プロンプトに表示される。本番環境は赤色警告。

```bash
# .envrc の例
layout_iac dev
use_aws_profile my-profile
use_gcp_project my-project-dev
```

## AI開発環境

Claude CodeとCodex CLIの設定もdotfilesでまとめている。

### Hook

`config/claude/settings.json` でライフサイクルフックを定義し、`bin/` 配下のスクリプトと連携。

| フック | スクリプト | 役割 |
|-------|----------|------|
| PreToolUse | `claude-guard-main-edit` | mainブランチでの編集をブロック |
| PreToolUse | `claude-suggest-compact` | コンテキスト肥大化を検知して圧縮を提案 |
| PostToolUse | `claude-commit-log` | コミットログを整形・記録 |
| PreCompact | `claude-pre-compact` | 圧縮前に保持すべき情報を退避 |
| Stop | `claude-session-end` | セッション終了時の後処理 |

間違った操作をする前に止める、操作直後に検証する、の順で問題を早く検出する。

### Skills

`config/claude/skills/` に30以上配置。Claude Codeが文脈に応じて自動で選ぶワークフロー定義。

- `review-pr` — PRレビューとフィードバック
- `post-merge` — マージ後のLinear更新、ブランチ削除、デフォルトブランチ同期
- `vibe-start` → `vibe-plan` → `vibe-review` — 設計から実装・レビューまで
- `codex-review` — Codex CLIをセカンドオピニオンとして呼ぶ

### Rules

`config/claude/rules/` にプロジェクト横断の行動ルールを配置。

- `workflow.md` — PR作成手順、コード品質の原則
- `codex-collaboration.md` — Claude Codeが実装、Codexが検証、の役割分担
- `knowledge-search.md` — 社内ナレッジ検索のパラメータガイド
- `automation.md` — 繰り返し作業を検知してSkill化を提案

### Permission

`settings.json` でClaude Codeが実行できるコマンドを三層で制御。

- `allow` — 自動実行。`git`, `gh`, `mise`, 読み取り系コマンドなど
- `deny` — 実行禁止。`rm -rf`, mainへのforce push, 機密ファイルの読み取りなど
- `ask` — 実行前に確認。`git push`, `curl`, `wget`

npm/yarn/npxは `deny` に入れ、pnpmのみ許可。サプライチェーン対策。

## セットアップ

### クイックスタート

```bash
# 1. Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# 2. clone & install
brew install git
mkdir -p ~/gh/ryosukesuto
git clone https://github.com/ryosukesuto/dotfiles.git ~/gh/ryosukesuto/dotfiles
cd ~/gh/ryosukesuto/dotfiles
./install.sh

# 3. ツール一括インストール
./install.sh --brew
```

### install.shがやること

1. シンボリックリンクの作成 — zsh, git, ssh, tmux, vim, claude, codex, mise, direnv, ghostty, npm, uv
2. dotfiles-privateの検出と機密ファイルのリンク
3. Git hooksのセットアップ — mainブランチ保護
4. mise経由のツールインストール
5. corepack経由のpnpm有効化
6. Claude Code, Claude Desktop, Codex CLI, Deno, Biome等のインストール

リンク済みのファイルはスキップ。冪等。

| オプション | 説明 |
|-----------|------|
| `-d, --dry-run` | 実際には変更せず確認のみ |
| `-f, --force` | 確認プロンプトをスキップ |
| `-n, --no-backup` | 既存ファイルのバックアップを作成しない |
| `-c, --clean-backup` | インストール後にバックアップファイルを削除 |
| `--brew` | Brewfileからツールを一括インストール |
| `--check-deps` | 依存関係のチェックのみ |

### 手動設定

```bash
# Gitユーザー情報
cat > ~/.gitconfig.local << 'EOF'
[user]
    name = Your Name
    email = your.email@example.com
EOF

# SSH鍵
ssh-keygen -t ed25519 -C "your.email@example.com"
# https://github.com/settings/keys に公開鍵を登録

# AIツール認証
claude   # Anthropic APIキーまたはOAuth
codex    # OpenAI APIキー
```

## 構成

```
zsh/               Zsh設定、番号プレフィクスで読み込み順を制御
  00-core.zsh        コアシェル設定
  20-path.zsh        PATH管理
  40-functions.zsh   カスタム関数
  50-tools.zsh       mise/direnv初期化
  60-prompt.zsh      プロンプト、ENV/AWS警告
  90-local.zsh       マシン固有の設定、.local読み込み
config/            アプリ設定
  claude/            Claude Code — settings.json, skills/, rules/
  codex/             Codex CLI — config.toml, AGENTS.md
  direnv/            direnv、環境変数自動切替
  git/               Git — gitconfig, hooks/
  ghostty/           Ghosttyターミナル
  fzf/               fzf
  gh/                GitHub CLI
  mise/              mise、node/uv等のバージョン管理
  npm/               npmrc、pnpmハードニング
  ssh/               SSH
  tmux/              tmux
  uv/                uv、Pythonパッケージ管理
  vim/               Vim
bin/               カスタムスクリプト、Claude Code hooks
```

## ローカル設定

gitで管理されないマシン固有の設定:

| ファイル | 用途 |
|---------|------|
| `~/.gitconfig.local` | Git ユーザー情報 |
| `~/.env.local` | 環境変数 |
| `~/.zshrc.local` | マシン固有のzsh設定 |
| `*.local.md` | Claude Code/Codexの機密ルール。dotfiles-privateで管理 |
