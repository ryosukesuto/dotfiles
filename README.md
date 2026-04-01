# dotfiles

macOSの開発環境をコードで管理するリポジトリ。`git clone` → `./install.sh` で環境が再現できる。

## 設計の考え方

### publicリポジトリで機密を扱う

dotfilesをpublicにしている理由は、機密分離の強制力を得るため。「publicだから入れられない」という制約が、設定の構造化を促す。

機密情報（APIキー、プロジェクトID、内部URL等）は `dotfiles-private`（private repo）で管理し、`install.sh` がシンボリックリンクで自動配置する。publicリポジトリには `*.local.md` → `.gitignore` のパターンだけが存在し、中身は見えない。

```
dotfiles/           ← public: 構造とロジック
dotfiles-private/   ← private: 機密値
  config/claude/rules/foo.local.md  → dotfiles/config/claude/rules/foo.local.md (symlink)
```

### シンボリックリンクで即時反映

設定ファイルはコピーではなくシンボリックリンクで配置する。リポジトリを編集すれば即座に反映される。`install.sh` はリンク作成の冪等な実行スクリプトで、何度実行しても安全。

### ghq + git worktreeの二層構造

リポジトリ管理は `ghq`、ブランチ作業は `git worktree` で分離している。

`git checkout -b` は使わない。理由は、複数タスクを並行で進めるため。worktreeならブランチごとに独立したディレクトリを持てるので、AI（Claude Code / Codex）に別ブランチの作業を投げつつ、自分は別のブランチで手を動かせる。

```bash
ghq get github.com/org/repo          # リポジトリ取得
cd $(ghq root)/github.com/org/repo
git-wt add feature/xxx               # .worktrees/feature/xxx に作成
```

- `Ctrl+]`: ghqリポジトリをfzfで選択
- `Ctrl+\`: worktreeをfzfで選択
- mainへの直接コミットはpre-commitフックでブロック

### 環境切替はdirenvに任せる

プロジェクトごとのAWSプロファイル、GCPプロジェクト、環境名（dev/stg/prd）は `direnv` で自動切替する。`cd` するだけで環境変数がセットされ、プロンプトに表示される。本番環境は赤色で警告が出る。

```bash
# .envrc の例
layout_iac dev
use_aws_profile my-profile
use_gcp_project my-project-dev
```

## AI開発環境の設計

このリポジトリの特徴的な部分。Claude CodeとCodex CLIの設定をdotfilesで一元管理している。

### Hook: AIの行動にガードレールを張る

`config/claude/settings.json` でClaude Codeのフック（ライフサイクルイベント）を定義し、`bin/` 配下のスクリプトと連携させている。

| フック | スクリプト | 役割 |
|-------|----------|------|
| PreToolUse (Edit/Write) | `claude-guard-main-edit` | mainブランチでの編集をブロック |
| PreToolUse (Edit/Write) | `claude-suggest-compact` | コンテキスト肥大化を検知して圧縮を提案 |
| PostToolUse (Bash) | `claude-commit-log` | コミットログを整形・記録 |
| PreCompact | `claude-pre-compact` | 圧縮前に保持すべき情報を退避 |
| Stop | `claude-session-end` | セッション終了時の後処理 |

フックの設計思想は「フィードバックは速いほど価値が高い」。AIが間違った操作をする前に止める（PreToolUse）、操作直後に検証する（PostToolUse）、という順序で問題を検出する。

### Skills: 繰り返すワークフローを定型化する

`config/claude/skills/` に30以上のスキルを配置している。スキルはClaude Codeが文脈から自律的に選択する再利用可能なワークフロー定義。

例:
- `review-pr`: PRを体系的にレビューしてフィードバックを返す
- `post-merge`: マージ後にLinear更新、ブランチ削除、デフォルトブランチ同期を一括実行
- `vibe-start` → `vibe-plan` → `vibe-review`: 設計から実装・レビューまでの一貫ワークフロー
- `codex-review`: Codex CLIをセカンドオピニオンとして呼び出す

### Rules: プロジェクト横断の行動規範

`config/claude/rules/` にClaude Codeの行動ルールを置いている。ルールはすべてのプロジェクトで適用される。

- `workflow.md`: PR作成時の手順、コード品質の原則
- `codex-collaboration.md`: Claude Code（実装者）とCodex（検証者）の役割分担
- `knowledge-search.md`: 社内ナレッジ検索のパラメータガイド
- `automation.md`: 繰り返し作業を検知してSkill化を提案するルール

### Permission: allow/deny/askの三層制御

`settings.json` の `permissions` で、Claude Codeが実行できるコマンドを三層で制御している。

- `allow`: 自動実行を許可（`git`, `gh`, `mise`, 読み取り系コマンド等）
- `deny`: 実行を禁止（`rm -rf`, `git push --force origin main`, 機密ファイルの読み取り等）
- `ask`: 実行前に確認を求める（`git push`, `curl`, `wget`）

npm/yarn/npxは `deny` に入れて、pnpmのみを許可している（サプライチェーン対策）。

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

1. シンボリックリンクの作成（zsh, git, ssh, tmux, vim, claude, codex, mise, direnv, ghostty, npm, uv）
2. dotfiles-privateの検出と機密ファイルのリンク
3. Git hooksのセットアップ（mainブランチ保護）
4. mise経由のツールインストール
5. corepack経由のpnpm有効化
6. Claude Code / Claude Desktop / Codex CLI / Deno / Biome 等のインストール

既にリンク済みのファイルはスキップされる。何度実行しても安全（冪等）。

| オプション | 説明 |
|-----------|------|
| `-d, --dry-run` | 実際には変更せず確認のみ |
| `-f, --force` | 確認プロンプトをスキップ |
| `-n, --no-backup` | 既存ファイルのバックアップを作成しない |
| `-c, --clean-backup` | インストール後にバックアップファイルを削除 |
| `--brew` | Brewfileからツールを一括インストール |
| `--check-deps` | 依存関係のチェックのみ |

### 手動設定（必須）

```bash
# Gitユーザー情報
cat > ~/.gitconfig.local << 'EOF'
[user]
    name = Your Name
    email = your.email@example.com
EOF

# SSH鍵
ssh-keygen -t ed25519 -C "your.email@example.com"
# → https://github.com/settings/keys に公開鍵を登録

# AIツールの認証（初回起動時）
claude   # Anthropic APIキーまたはOAuth
codex    # OpenAI APIキー
```

## 構成

```
zsh/               Zsh設定（番号プレフィクスで読み込み順を制御）
  00-core.zsh        コアシェル設定
  20-path.zsh        PATH管理
  40-functions.zsh   カスタム関数
  50-tools.zsh       mise/direnv初期化
  60-prompt.zsh      プロンプト（ENV/AWS警告付き）
  90-local.zsh       マシン固有の設定（.local読み込み）
config/            アプリ設定
  claude/            Claude Code（settings.json, skills/, rules/）
  codex/             Codex CLI（config.toml, AGENTS.md）
  direnv/            direnv（環境変数自動切替）
  git/               Git（gitconfig, hooks/）
  ghostty/           Ghosttyターミナル
  fzf/               fzf
  gh/                GitHub CLI
  mise/              mise（node, uv等のバージョン管理）
  npm/               npmrc（pnpmハードニング）
  ssh/               SSH
  tmux/              tmux
  uv/                uv（Pythonパッケージ管理）
  vim/               Vim
bin/               カスタムスクリプト（Claude Code hooks + ユーティリティ）
```

## ローカル設定

gitで管理されないマシン固有の設定:

| ファイル | 用途 |
|---------|------|
| `~/.gitconfig.local` | Git ユーザー情報 |
| `~/.env.local` | 環境変数 |
| `~/.zshrc.local` | マシン固有のzsh設定 |
| `*.local.md` | Claude Code/Codexの機密ルール（dotfiles-privateで管理） |
