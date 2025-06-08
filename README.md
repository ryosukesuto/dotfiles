# dotfiles

個人用の設定ファイル（dotfiles）を管理するリポジトリです。

## 含まれる設定ファイル

- `.zshrc` - Zshの設定ファイル
- `.zprofile` - Zshのプロファイル設定
- `.gitconfig` - Gitの設定
- `.config/gh/` - GitHub CLIの設定

## セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/ryosukesuto/dotfiles.git ~/src/github.com/ryosukesuto/dotfiles
cd ~/src/github.com/ryosukesuto/dotfiles
```

### 2. インストールスクリプトの実行

```bash
./install.sh
```

このスクリプトは以下を実行します：
- 既存の設定ファイルをバックアップ（`.backup`拡張子を付けて保存）
- dotfilesリポジトリから各設定ファイルへのシンボリックリンクを作成

### 3. 設定の反映

新しいターミナルを開くか、以下のコマンドを実行して設定を反映します：

```bash
source ~/.zshrc
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