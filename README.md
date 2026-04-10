# dotfiles

AI開発特化型dotfiles

## 設計

### 機密情報の分離

```
dotfiles/           public: 構造とロジック
dotfiles-private/   private: 機密値（*.local.md → dotfiles/ 側に symlink）
```

### ghq + git worktree

リポジトリ管理は `ghq`、ブランチ作業は `git worktree` で行う。

複数タスクを並行で進めるため、通常のブランチは封印。

```bash
ghq get github.com/org/repo          # リポジトリ取得
cd $(ghq root)/github.com/org/repo
git-wt add feature/xxx               # .worktrees/feature/xxx に作成
```

- `Ctrl+]`: ghqリポジトリをfzfで選択
- `Ctrl+\`: worktreeをfzfで選択
- mainへの直接コミットはpre-commit hookでブロックする。

### direnvで環境切替

AWSプロファイル、GCPプロジェクト、環境名は `direnv` で制御。

```bash
# .envrc の例
layout_iac dev
use_aws_profile my-profile
use_gcp_project my-project-dev
```

## AI開発環境

### Hook

`config/claude/settings.json` でライフサイクルフックを定義、`bin/` 配下のスクリプトと連携。

| フック | スクリプト | 役割 |
|-------|----------|------|
| PreToolUse | `claude-guard-main-edit` | mainブランチでの編集をブロック |
| PreToolUse | `claude-suggest-compact` | コンテキスト肥大化を検知して圧縮を提案 |
| PostToolUse | `claude-commit-log` | コミットログを整形・記録 |
| PreCompact | `claude-pre-compact` | 圧縮前に保持すべき情報を退避 |
| Stop | `claude-session-end` | セッション終了時の後処理 |

### Skills

`config/claude/skills/` に配置。

- `review-pr` — Claude Code+Codexの協業PRレビュー
- `post-merge` — マージ後のLinear更新、ブランチ削除、デフォルトブランチ同期
- `vibe-start` → `vibe-plan` → `vibe-review` — バイブコーディング用Skill
- `codex-review` — Codex CLIをセカンドオピニオンとして呼ぶ

### Rules

`config/claude/rules/` にプロジェクト横断のルールを配置。

- `knowledge-search.md` — 社内ナレッジ検索のパラメータガイド

### Permission

`settings.json` でClaude Codeが実行できるコマンドを三層で制御。

- `allow` — 自動実行。`git`, `gh`, `mise`, 読み取り系コマンドなど
- `deny` — 実行禁止。`rm -rf`, mainへのforce push, 機密ファイルの読み取りなど
- `ask` — 実行前に確認。`git push`, `curl`, `wget`

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

### install.sh

1. シンボリックリンクの作成 — zsh, git, ssh, tmux, vim, claude, codex, mise, direnv, ghostty, npm, uv
2. dotfiles-privateの検出と機密ファイルのリンク
3. Git hooksのセットアップ — mainブランチ保護
4. mise経由のツールインストール
5. corepack経由のpnpm有効化
6. Claude Code, Claude Desktop, Codex CLI, Deno, Biome等のインストール

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

| ファイル | 用途 |
|---------|------|
| `~/.gitconfig.local` | Git ユーザー情報 |
| `~/.env.local` | 環境変数 |
| `~/.zshrc.local` | マシン固有のzsh設定 |
| `*.local.md` | Claude Code/Codexの機密ルール。dotfiles-privateで管理 |
