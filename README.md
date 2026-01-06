# dotfiles

個人用の設定ファイル（dotfiles）を管理するリポジトリです。

## セットアップ

```bash
git clone https://github.com/ryosukesuto/dotfiles.git ~/gh/ryosukesuto/dotfiles
cd ~/gh/ryosukesuto/dotfiles
./install.sh
```

### オプション

- `-f, --force` - 確認なしでインストール
- `-n, --no-backup` - バックアップを作成しない
- `-d, --dry-run` - 実際には変更を加えずに確認

## 構成

```
zsh/           - Zsh設定（番号順に読み込み）
config/        - アプリ設定（git, gh, tmux, vim, ssh, aws, claude, codex）
bin/           - カスタムスクリプト
```

## 主な機能

- ghq + fzf によるリポジトリナビゲーション (Ctrl+])
- mise によるバージョン管理
- モダンツール: eza, bat, rg (エイリアスで自動置換)
- AWS SSM Session Manager 統合

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

- `~/.gitconfig.local` - Git ユーザー情報
- `~/.env.local` - 環境変数
- `~/.zshrc.local` - マシン固有のzsh設定

## セキュリティ

- 認証情報はコミットしない
- 機密設定は `.local` ファイルへ
- AWS設定はテンプレート方式
