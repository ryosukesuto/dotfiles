# dotfiles

個人用の設定ファイル（dotfiles）を管理するリポジトリです。

## 新しいPCのセットアップ

### 1. Homebrewをインストール

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# M1/M2 Macの場合、パスを追加
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 2. リポジトリをクローン

```bash
brew install git
mkdir -p ~/gh/ryosukesuto
git clone https://github.com/ryosukesuto/dotfiles.git ~/gh/ryosukesuto/dotfiles
cd ~/gh/ryosukesuto/dotfiles
```

### 3. dotfilesをインストール

```bash
# ドライランで確認（任意）
./install.sh --dry-run

# 実行
./install.sh
```

### 4. ツールをインストール

```bash
./install.sh --brew
```

### 5. SSH鍵の生成

```bash
# ED25519鍵を生成（推奨）
ssh-keygen -t ed25519 -C "your.email@example.com"

# 公開鍵を表示してコピー
cat ~/.ssh/id_ed25519.pub
```

GitHubに登録: https://github.com/settings/keys → `New SSH key`

### 6. 手動設定（必須）

```bash
# Gitユーザー情報
cat > ~/.gitconfig.local << 'EOF'
[user]
    name = Your Name
    email = your.email@example.com
EOF
```

### 7. 設定を反映

```bash
# 新しいターミナルを開く、または
source ~/.zshrc
```

### 8. AIツールの認証

install.shで自動インストールされます:
- Claude Code: ネイティブインストール（推奨）
- Codex CLI: npm

初回起動時に認証:

```bash
# Claude Code（Anthropic APIキーまたはOAuth）
claude

# Codex（OpenAI APIキー）
codex
```

### 9. 追加セットアップ（任意）

```bash
# mise でツールをインストール
mise install

# GitHub CLI認証
gh auth login
```

### install.shオプション

| オプション | 説明 |
|-----------|------|
| `-f, --force` | 確認なしでインストール |
| `-n, --no-backup` | バックアップを作成しない |
| `-d, --dry-run` | 実際には変更を加えずに確認 |
| `--brew` | Brewfileからツールをインストール |
| `--check-deps` | 依存関係のチェックのみ |

## AWS認証

フェデレーション認証方式を使用:

1. https://federation.perman.jp/#/ にログイン
2. `aws-winticket` の `...` → `一時的な認証情報を取得`
3. `環境変数の設定` の `コピー` をクリック
4. ターミナルで貼り付けて実行

## 構成

```
zsh/           - Zsh設定（番号順に読み込み）
config/        - アプリ設定（git, gh, tmux, vim, ssh, claude, codex）
bin/           - カスタムスクリプト
```

## 主な機能

- ghq + fzf によるリポジトリナビゲーション (Ctrl+])
- mise によるバージョン管理
- モダンツール: eza, bat, rg (エイリアスで自動置換)
- Claude Code / Codex CLI 統合

## エイリアス

```bash
# Git
g, gs, ga, gc, gp, gl, gd, gb, gco

# tmux
t, ta, tl

# その他
reload  # 設定再読み込み
path    # PATH表示
```

## ローカル設定

gitで管理されないマシン固有の設定：

| ファイル | 用途 |
|---------|------|
| `~/.gitconfig.local` | Git ユーザー情報 |
| `~/.env.local` | 環境変数 |
| `~/.zshrc.local` | マシン固有のzsh設定 |

## セキュリティ

- 認証情報はコミットしない
- 機密設定は `.local` ファイルへ
- AWS設定はフェデレーション認証（環境変数方式）
