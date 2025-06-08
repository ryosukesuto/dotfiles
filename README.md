# dotfiles

個人用の設定ファイル（dotfiles）を管理するリポジトリです。

## 構造

```
.
├── zsh/                  # Zsh設定（モジュール化）
│   ├── 00-base.zsh      # 基本設定
│   ├── 10-history.zsh   # 履歴設定
│   ├── 20-path.zsh      # PATH設定
│   ├── 30-functions.zsh # カスタム関数
│   ├── 40-tools.zsh     # ツール設定
│   └── 90-project.zsh   # プロジェクト固有設定
├── git/                  # Git設定
│   └── gitconfig
├── config/              # 各種アプリケーション設定
│   └── gh/              # GitHub CLI
├── .zshrc               # メインのZsh設定（モジュールを読み込み）
├── .zprofile            # Zshプロファイル
├── install.sh           # インストールスクリプト
├── uninstall.sh         # アンインストールスクリプト
└── Makefile             # 便利なコマンド集
```

## セットアップ

### クイックスタート

```bash
git clone https://github.com/ryosukesuto/dotfiles.git ~/src/github.com/ryosukesuto/dotfiles
cd ~/src/github.com/ryosukesuto/dotfiles
make install
```

### 手動インストール

```bash
./install.sh
```

オプション：
- `-h, --help` - ヘルプを表示
- `-f, --force` - 確認なしでインストール
- `-n, --no-backup` - バックアップを作成しない

### Makefileを使った操作

```bash
make help          # 使用可能なコマンドを表示
make install       # dotfilesをインストール
make uninstall     # dotfilesをアンインストール
make update        # リポジトリを更新して再インストール
make backup        # 現在の設定をバックアップ
make clean         # バックアップファイルを削除
```

## 設定の詳細

### Zsh設定 (.zshrc)

- **パス設定**: tfenv、Go binaries
- **履歴設定**: 50,000行の履歴を保持、重複を除外
- **キーバインド**: Emacsモード
- **カスタム関数**: `peco-src` - ghqとpecoを使った高速ディレクトリ移動（Ctrl+]）
- **ツール設定**: pyenv、Terraform補完、DBT環境変数

### Git設定 (.gitconfig)

- ユーザー情報の設定
- ghqのルートディレクトリ設定（~/src）

## バックアップとリストア

インストールスクリプトは既存のファイルを`.backup`拡張子付きで自動バックアップします。
元の設定に戻したい場合は、バックアップファイルをリネームしてください：

```bash
mv ~/.zshrc.backup ~/.zshrc
```

## 更新方法

1. 設定ファイルを直接編集
2. 変更をコミット＆プッシュ

```bash
git add .
git commit -m "設定を更新"
git push
```

他のマシンで更新を反映する場合：

```bash
git pull
./install.sh
```