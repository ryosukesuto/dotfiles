# dotfiles

個人用の設定ファイル（dotfiles）を管理するリポジトリです。

## 構造

```
.
├── aws/                  # AWS CLI設定（テンプレート）
│   ├── config.template  # AWS設定テンプレート（SSO対応）
│   └── credentials.template  # AWS認証情報テンプレート
├── config/              # 各種アプリケーション設定
│   └── gh/              # GitHub CLI設定
│       ├── config.yml
│       └── hosts.yml
├── git/                 # Git設定
│   └── gitconfig       # エイリアス・色設定強化
├── ssh/                 # SSH設定
│   ├── config          # SSH接続設定（効率化・セキュリティ強化）
│   └── ssh-utils.sh    # SSH管理ユーティリティスクリプト
├── tmux/                # tmux設定
│   └── tmux.conf       # 高機能なターミナルマルチプレクサ設定
├── vim/                 # Vim設定
│   └── vimrc           # モダンなVim環境（プラグイン管理込み）
├── zsh/                 # Zsh設定（モジュール化）
│   ├── 00-base.zsh     # 基本設定・補完・オプション
│   ├── 10-history.zsh  # 履歴設定（セキュリティ強化）
│   ├── 20-path.zsh     # PATH・環境変数管理
│   ├── 25-aliases.zsh  # エイリアス（モダンツール対応）
│   ├── 30-functions.zsh # カスタム関数（fzf/peco対応）
│   ├── 40-tools.zsh    # ツール設定（遅延初期化）
│   ├── 50-prompt.zsh   # プロンプトカスタマイズ
│   └── 90-project.zsh  # プロジェクト固有設定
├── CLAUDE.md            # Claude Code用技術ガイド
├── install.sh           # インストールスクリプト（改良版）
├── Makefile             # 便利なコマンド集
├── ONBOARDING.md        # ツール・エイリアス使い方ガイド
├── README.md            # このファイル
└── uninstall.sh         # アンインストールスクリプト
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

## 📚 ドキュメント

- **[ONBOARDING.md](ONBOARDING.md)** - 便利なツールやエイリアスの使い方ガイド
- **[CLAUDE.md](CLAUDE.md)** - Claude Code用の技術ガイド

## 主な機能・改善点

### 🚀 パフォーマンス最適化
- **プロンプトキャッシュシステム**: 30秒間ツールチェック結果をキャッシュして表示高速化
- **遅延読み込み**: pyenv、rbenv、nodenv、terraform、GitHub CLIの初回実行時初期化
- **補完システム最適化**: 24時間キャッシュ+重複パス削除で起動高速化
- **効率的なPATH管理**: 重複チェック付きPATH追加関数

### 🔒 セキュリティ強化
- **履歴ファイル保護**: 適切なパーミッション設定（600）
- **機密情報分離**: `.env.local`、`.gitconfig.local`で個人情報管理
- **AWS設定保護**: テンプレート方式で機密情報を除外
- **XDG Base Directory**: 設定ファイルの標準化

### 🛠 モダンツール対応
- **SSH設定強化**: 接続の高速化・再利用・セキュリティ強化
- **SSH管理ツール**: 鍵生成・接続テスト・セキュリティチェック
- **AWS SSM統合**: 踏み台サーバーへの簡単接続（`bastion`コマンド）
- **fzf統合**: 履歴検索・ファイル検索・ディレクトリ移動
- **モダンコマンド**: eza (ls)、bat (cat)、rg (grep)、fd (find)
- **Git強化**: 豊富なエイリアス・色設定・便利な設定

### 🎨 UX改善
- **インテリジェントプロンプト**: Git状態・Python/Node/Go/AWS/Terraform/K8s環境表示（キャッシュ対応）
- **システム診断機能**: `dotfiles-diag`でツールインストール状況を一括確認
- **便利なエイリアス**: Git、Docker、Kubernetes対応、動的パス解決
- **実行時間測定**: 長時間コマンド（5秒以上）の実行時間表示
- **補完エラー修正**: ファイル・ディレクトリ名補完の信頼性向上

### ☁️ AWS SSM セッション管理
AWS Systems Manager Session Managerを使った踏み台サーバーへの接続を簡素化：

```bash
# デフォルト（prod環境）の踏み台サーバーへ接続
bastion

# 特定環境の踏み台サーバーへ接続
bastion-dev      # 開発環境
bastion-staging  # ステージング環境
bastion-prod     # 本番環境

# インスタンスを選択して接続（fzfを使用）
bastion-select

# カスタムパラメータで接続
aws-bastion <profile> <instance-id> <region>
```

機能：
- 自動的にAWS SSOにログイン
- 環境別のエイリアスで簡単アクセス
- fzfを使った対話的なインスタンス選択
- Name タグに "bastion" を含むインスタンスを優先表示

## 設定の詳細

### Zsh設定の特徴

- **モジュール化**: 機能別ファイル分割で保守性向上
- **パフォーマンス最適化**: プロンプトキャッシュ、遅延読み込み、効率的補完
- **履歴管理**: 50,000行、重複除去、実行時間記録
- **補完強化**: 大文字小文字無視、メニュー選択、色付け、ファイル名補完
- **関数群**: mkcd、extract、gacp、port、dotfiles-diagなど便利関数
- **エラー対策**: 補完システム初期化エラーの解決

### Git設定の特徴

- **pull.rebase**: マージコミットを作らないpull
- **push.autoSetupRemote**: 初回pushで自動的にupstream設定
- **diff.colorMoved**: 移動したコードの可視化
- **豊富なエイリアス**: 日常的なGit操作を短縮

## バックアップとリストア

インストールスクリプトは既存のファイルを`.backup`拡張子付きで自動バックアップします。
元の設定に戻したい場合は、バックアップファイルをリネームしてください：

```bash
mv ~/.zshrc.backup ~/.zshrc
```

## 便利なコマンド

### システム診断
環境のセットアップ状況を確認：

```bash
dotfiles-diag
```

このコマンドで以下を確認できます：
- 必須ツールのインストール状況
- 設定ファイルの存在確認
- パフォーマンス情報（キャッシュ状況など）

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

## セキュリティについて

このdotfilesリポジトリは公開リポジトリとして安全に設計されています：

### 🔒 機密情報の保護
- **個人情報の分離**: メールアドレス、API キーなどは `.gitconfig.local`、`.env.local` で管理
- **履歴の保護**: シェル履歴やツール設定ファイルは `.gitignore` で除外
- **環境変数**: プロジェクト固有の機密情報は環境変数ファイルで管理

### 📁 ローカル設定ファイル
以下のファイルは **Gitで管理されません**（各マシンで個別作成）：

```bash
# Git ユーザー情報
~/.gitconfig.local
[user]
    name = Your Name
    email = your.email@example.com

# AWS設定（テンプレートからコピー）
~/.aws/config
~/.aws/credentials

# 環境変数（機密情報）
~/.env.local
export DBT_PROJECT_ID=your-secret-project-id
export API_KEY=your-secret-key

# マシン固有のzsh設定
~/.zshrc.local
# マシン固有の設定をここに記述
```

### ⚠️ 注意事項
- **機密情報は絶対にコミットしない**
- **新しい設定ファイルを追加する際は機密情報をチェック**
- **`.env.local`、`*.local` ファイルは `.gitignore` で除外済み**