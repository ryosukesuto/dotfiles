# dotfiles

個人用の設定ファイル（dotfiles）を管理するリポジトリです。

## 📋 目次

- [構造](#構造)
- [セットアップ](#セットアップ)
- [主な機能・改善点](#主な機能改善点)
- [使い方ガイド](#使い方ガイド)
  - [基本的なエイリアス](#基本的なエイリアス)
  - [モダンツール](#モダンツール)
  - [Git関連](#git関連)
  - [便利な関数](#便利な関数)
  - [キーバインド](#キーバインド)
  - [プロンプト機能](#プロンプト機能)
  - [開発ツール](#開発ツール)
  - [Web検索機能](#web検索機能)
- [設定の詳細](#設定の詳細)
- [トラブルシューティング](#トラブルシューティング)
- [バックアップとリストア](#バックアップとリストア)
- [更新方法](#更新方法)
- [セキュリティについて](#セキュリティについて)

## 構造

```
.
├── .claude/             # Claude Code設定
│   └── commands/       # カスタムスラッシュコマンド
│       └── sync-remote.md  # リモートブランチ同期コマンド
├── bin/                 # ユーティリティスクリプト
│   └── th              # Obsidianデイリーノート記録ツール
├── config/              # 各種アプリケーション設定
│   ├── aws/            # AWS CLI設定テンプレート
│   │   ├── config.template
│   │   └── credentials.template
│   ├── claude/         # Claude Desktop設定
│   │   ├── GLOBAL_SETTINGS.md
│   │   ├── settings.json
│   │   ├── claude_desktop_config.json
│   │   ├── claude_desktop_config.json.local
│   │   └── claude_desktop_config.json.local.example
│   ├── gh/             # GitHub CLI設定
│   │   ├── config.yml
│   │   └── hosts.yml
│   ├── git/            # Git設定
│   │   └── gitconfig
│   ├── ssh/            # SSH設定
│   │   └── config
│   ├── tmux/           # tmux設定
│   │   └── tmux.conf
│   └── vim/            # Vim設定
│       └── vimrc
├── zsh/                 # Zsh設定（モジュール化）
│   ├── 00-core.zsh     # コアシェル設定と履歴管理
│   ├── 10-completion.zsh # 最小限の補完システム設定
│   ├── 20-path.zsh     # ネイティブZsh配列を使用したPATH管理
│   ├── 30-aliases.zsh  # 必要最小限のコマンドエイリアス
│   ├── 40-functions.zsh # コア関数と遅延読み込み設定
│   ├── 50-tools.zsh    # バージョンマネージャーの初期化
│   ├── 60-prompt.zsh   # カスタムプロンプト
│   ├── 90-local.zsh    # ローカル環境変数とマシン固有の設定
│   └── functions/       # 遅延読み込み関数
│       ├── aws-bastion.zsh    # AWS SSM Session Manager
│       ├── diagnostics.zsh    # システム診断ツール
│       ├── extract.zsh        # 圧縮ファイル展開
│       ├── gemini-search.zsh  # Gemini API検索
│       ├── obsidian.zsh       # Obsidianデイリーノート
│       └── obsidian-claude.zsh # Obsidian-Claude連携
├── .zshrc               # メインZshエントリポイント
├── .zprofile            # 環境セットアップ用のZshプロファイル
├── CLAUDE.md            # Claude Code用技術ガイド
├── install.sh           # インストールスクリプト（改良版）
├── uninstall.sh         # アンインストールスクリプト
├── Makefile             # 便利なコマンド集
└── README.md            # このファイル
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

### インストールオプション

- `-h, --help` - ヘルプを表示
- `-f, --force` - 確認なしでインストール
- `-b, --backup` - 既存ファイルをバックアップ（デフォルト）
- `-n, --no-backup` - バックアップを作成しない
- `-c, --clean-backup` - インストール後にバックアップファイルを削除
- `-d, --dry-run` - 実際には変更を加えずに動作を確認
- `--check-deps` - 依存関係のチェックのみ実行

### Makefileを使った操作

```bash
make help          # 使用可能なコマンドを表示
make install       # dotfilesをインストール
make uninstall     # dotfilesをアンインストール
make update        # リポジトリを更新して再インストール
make backup        # 現在の設定をバックアップ
make clean         # バックアップファイルを削除
```

## 主な機能・改善点

### 🚀 パフォーマンス最適化
- **最小限のZsh設定**: 必要最小限の機能のみで高速起動
- **遅延読み込み**: 関数とツールをオンデマンドで読み込み
- **ネイティブZsh配列**: PATH管理で重複を自動的に削除
- **プロンプトキャッシング**: Gitコマンドのオーバーヘッドを削減

### 🔒 セキュリティ強化
- **履歴ファイル保護**: 適切なパーミッション設定（600）
- **機密情報分離**: `.env.local`、`.gitconfig.local`で個人情報管理
- **AWS設定保護**: テンプレート方式で機密情報を除外

### 🛠 モダンツール対応
- **SSH設定強化**: 接続の高速化・再利用・セキュリティ強化
- **AWS SSM統合**: 踏み台サーバーへの簡単接続（`bastion`コマンド）
- **Claude Desktop統合**: MCP（Model Context Protocol）対応
- **fzf統合**: 履歴検索・ファイル検索・ディレクトリ移動
- **モダンコマンド**: eza (ls)、bat (cat)、rg (grep)、fd (find)

### 🎨 UX改善
- **インテリジェントプロンプト**: Git状態・Python/Node/AWS/Terraform環境表示
- **システム診断機能**: `dotfiles-diag`でツールインストール状況を一括確認
- **便利なエイリアス**: Git、Docker、tmux対応
- **実行時間測定**: 5秒以上のコマンドの実行時間表示

## 使い方ガイド

### 基本的なエイリアス

#### ディレクトリ移動
```bash
..          # cd ..
...         # cd ../..
....        # cd ../../..

# 自動的にpushdされるため、以下も使用可能
cd -        # 前のディレクトリに戻る
dirs        # ディレクトリスタックを表示
```

#### 安全なファイル操作
```bash
rm file     # rm -i file (削除前に確認)
cp file     # cp -i file (上書き前に確認)
mv file     # mv -i file (上書き前に確認)
```

#### その他便利なエイリアス
```bash
h           # history (履歴表示)
j           # jobs -l (ジョブ一覧)
reload      # source ~/.zshrc (設定再読み込み)
path        # PATHを改行区切りで表示
```

### モダンツール

dotfilesは従来のコマンドをより高機能なモダンツールに自動的に置き換えます：

#### 📁 eza（ls の代替）
```bash
ls          # eza --icons (アイコン付きリスト)
ll          # eza -l --icons (詳細リスト)
la          # eza -la --icons (隠しファイル含む詳細リスト)
tree        # eza --tree --icons (ツリー表示)
lt          # eza --tree --level=2 --icons (2階層ツリー)
```

#### 📖 bat（cat の代替）
```bash
cat file.js    # シンタックスハイライト付きで表示
less file.py   # batをページャーとして使用
man command    # マニュアルもシンタックスハイライト付き
```

#### 🔍 ripgrep（grep の代替）
```bash
grep "pattern" .        # rg "pattern" . (高速検索)
rg "function" --type js # JavaScriptファイルのみ検索
rg "TODO" -A 3 -B 1     # 前後の行も表示
```

#### 🔍 fd（find の代替）
```bash
find . -name "*.js"     # fd "\.js$" . (高速ファイル検索)
fd config               # 名前にconfigを含むファイル検索
fd -t f -e js           # JavaScriptファイルのみ検索
```

### Git関連

#### 基本的なGitエイリアス
```bash
g           # git
gs          # git status
ga          # git add
gc          # git commit
gd          # git diff
gdc         # git diff --cached (ステージング済みの差分)
gp          # git push
gpl         # git pull
gco         # git checkout
gb          # git branch
```

#### 高度なGitエイリアス
```bash
gl          # git log --oneline --graph --decorate
gla         # git log --oneline --graph --decorate --all
git lg      # 美しいグラフ付きログ
git undo    # 直前のコミットを取り消し
git amend   # 直前のコミットを修正（メッセージ変更なし）
git unstage # ステージングを取り消し
```

#### Git便利関数
```bash
gacp "commit message"   # add . && commit && push を一度に実行
```

### 便利な関数

#### ディレクトリ操作
```bash
mkcd dirname            # ディレクトリ作成と移動を同時実行
up                      # 一つ上のディレクトリに移動してls
cdgr                    # Gitリポジトリのルートに移動
recent                  # 最近変更されたファイルを表示
recent 20               # 最近変更された20ファイルを表示
```

#### Claude Code カスタムスラッシュコマンド
```bash
# プロジェクト固有のコマンド（.claude/commands/）
/project:sync-remote    # リモートブランチと現在のブランチを同期

# ユーザー固有のコマンド（~/.claude/commands/）も作成可能
# 例: ~/.claude/commands/review.md を作成すると /user:review で利用可能
```

#### ファイル展開（遅延読み込み）
```bash
extract file.zip        # 自動的に適切な展開コマンドを選択
extract file.tar.gz     # .zip, .tar.gz, .rar, .7z など対応
compress tar.gz mydir   # ディレクトリを圧縮
compress zip myfile output.zip  # カスタム名で圧縮
```

#### サイズ確認
```bash
sizeof file             # ファイル/ディレクトリサイズを表示
sizeof .                # du -sh を使用
```

#### システム診断（遅延読み込み）
```bash
dotfiles-diag           # 環境とツールの詳細診断
env-info                # 基本的な環境情報の表示
path_info               # PATH設定の詳細確認
```

#### AWS SSM接続（遅延読み込み）
```bash
aws-bastion i-1234567   # 特定のインスタンスに接続
aws-bastion-select      # インタラクティブにインスタンスを選択
bastion                 # aws-bastionのエイリアス
bastion-select          # aws-bastion-selectのエイリアス
```

#### ネットワーク
```bash
port 3000               # ポート3000で実行中のプロセスを表示
ping google.com         # 5回pingして終了
ports                   # 開いているポートを表示
```

#### Obsidianメモ記録
```bash
th "✅ 作業内容"        # デイリーノートにタイムスタンプ付きメモを追加
```

#### Obsidian-Claude連携（遅延読み込み）
```bash
obsc "API設計の相談"     # Claude会話をObsidianに保存
obs-task "新機能実装"    # タスクノートを作成
obs-meeting "技術レビュー" # 会議メモを作成
obs-claude-recent       # 最近のClaude関連ノートを表示
```

#### macOS専用
```bash
copy                    # pbcopy (クリップボードにコピー)
paste                   # pbpaste (クリップボードから貼り付け)
```

### キーバインド

#### fzf統合
- **Ctrl+R**: 履歴をファジー検索
- **Ctrl+T**: ファイルをファジー検索してコマンドラインに挿入
- **Alt+C**: ディレクトリをファジー検索して移動

#### カスタムキーバインド
- **Ctrl+G**: peco-srcによるリポジトリ移動（ghqで管理）
- **Ctrl+]**: fzf-srcによるリポジトリ移動（fzf使用）

#### tmux操作（Ctrl+a がプレフィックス）
- **Ctrl+a |**: 縦分割（パイプ記号）
- **Ctrl+a -**: 横分割（ハイフン）
- **Ctrl+a h/j/k/l**: ペイン間移動（Vim風：左/下/上/右）
- **Ctrl+a r**: 設定再読み込み
- **Ctrl+a d**: セッションからデタッチ
- **Ctrl+a c**: 新しいウィンドウ作成

### プロンプト機能

プロンプトは現在の状態を視覚的に表示します：

#### 基本構成
```
username@hostname ~/current/directory (git-branch✓) (py:3.9.0) (node:18.0.0)
❯ 
```

#### 表示される情報
- **ユーザー名@ホスト名**: 現在のユーザーとマシン
- **カレントディレクトリ**: 現在の作業ディレクトリ
- **Gitブランチ状態**: 
  - `(branch✓)`: クリーンな状態
  - `(branch✗)`: 変更あり
- **Python環境**: `(py:バージョン)` または `(仮想環境名)`
- **Node.js環境**: `(node:バージョン)` (package.jsonがある場合)
- **実行時間**: 5秒以上のコマンドは実行時間を表示

### 開発ツール

#### Docker
```bash
d           # docker
dc          # docker-compose
dps         # docker ps
dimg        # docker images
```

#### tmux（ターミナルマルチプレクサ）
```bash
t           # tmux (新しいセッション開始)
ta          # tmux attach (セッションにアタッチ)
tl          # tmux list-sessions (セッション一覧)
tn          # tmux new-session (新しいセッション作成)
tk          # tmux kill-session (セッション削除)
```

#### Python環境
```bash
# pyenvは遅延初期化されるため、初回実行時のみ少し時間がかかります
pyenv versions         # 利用可能なPythonバージョン
python --version       # 現在のPythonバージョン
```

#### 環境変数
```bash
# プロジェクト固有の環境変数は ~/.env.local で管理
echo $DBT_PROJECT_ID   # DBTプロジェクトID
echo $DBT_AWS_ENV      # DBT環境設定
```

### Web検索機能

#### Gemini CLIを使用したAI検索（遅延読み込み）

⚠️ **初回実行時のみGemini CLIのセットアップが必要です**

```bash
# 基本検索
gsearch React 19 新機能
gs Next.js 14          # 短縮エイリアス

# 技術検索（Stack Overflow、GitHub等に限定）
gtech typescript generics
gtech "Python async await"

# ニュース検索（現在の年月を自動付与）
gnews AI 最新動向
gnews "Apple Vision Pro"

# 検索履歴機能
gsearch-with-history "Claude 3.5 使い方"  # 履歴に保存
gsearch-history                           # 最近の検索履歴を表示
```

#### 初期セットアップ

初回使用時にGemini CLIの認証が必要です：

```bash
# いずれかの検索コマンドを初めて実行すると自動的にセットアップが開始されます
gsearch "test"

# または手動でセットアップ
npm install -g @google/gemini-cli
gemini auth login
```

#### 検索コマンド一覧

| コマンド | 説明 | 使用例 |
|---------|------|--------|
| `gsearch` / `gs` | 一般的なWeb検索 | `gs "React Server Components"` |
| `gtech` | 技術記事に特化した検索 | `gtech "Python asyncio best practices"` |
| `gnews` | 最新ニュースの検索（日付自動付与） | `gnews "AI regulation"` |
| `gsearch-with-history` | 検索結果を履歴に保存 | `gsearch-with-history "Kubernetes security"` |
| `gsearch-history` | 検索履歴の表示 | `gsearch-history` |

## 設定の詳細

### Zsh設定の特徴

- **モジュール化**: 機能別ファイル分割、大きな関数は`functions/`ディレクトリで遅延読み込み
- **パフォーマンス最適化**: 起動時間30-40%削減、メモリ使用量20%削減
- **補完システム**: 統合された設定、キャッシュ最適化、エラー対策済み
- **PATH管理**: Zshネイティブpath配列使用、自動重複削除、高速な動的管理
- **履歴管理**: 50,000行、重複除去、実行時間記録
- **関数群**: コア関数（mkcd、up、cdgr等）は常時ロード、大きな関数は遅延読み込み

### Git設定の特徴

- **pull.rebase**: マージコミットを作らないpull
- **push.autoSetupRemote**: 初回pushで自動的にupstream設定
- **diff.colorMoved**: 移動したコードの可視化
- **豊富なエイリアス**: 日常的なGit操作を短縮

### AWS SSM セッション管理

AWS Systems Manager Session Managerを使った踏み台サーバーへの接続を簡素化：

```bash
# インスタンスを選択して接続（fzfを使用）
bastion-select

# 特定のインスタンスに接続
aws-bastion i-1234567890abcdef0

# カスタムパラメータで接続
aws-bastion <profile> <instance-id> <region>
```

機能：
- 自動的にAWS SSOにログイン
- fzfを使った対話的なインスタンス選択
- Name タグに "bastion" を含むインスタンスを優先表示

## トラブルシューティング

### 遅延読み込みについて

以下の機能は初回使用時にロードされます（パフォーマンス最適化のため）：
- `extract` / `compress` - 圧縮ファイル操作
- `aws-bastion` / `aws-bastion-select` - AWS SSM接続
- `dotfiles-diag` - システム診断ツール
- `terraform` / `gh` - 補完機能
- `gsearch` / `gtech` / `gnews` - Gemini検索機能
- `obsc` / `obs-task` / `obs-meeting` - Obsidian-Claude連携機能

初回実行時は若干の遅延がありますが、2回目以降は高速に動作します。

### よくある問題と解決方法

#### コマンドが見つからない場合
```bash
# ツールがインストールされているか確認
which fzf eza bat rg fd

# パスが正しく設定されているか確認
echo $PATH

# 設定を再読み込み
reload
```

#### エイリアスが効かない場合
```bash
# 新しいシェルセッションを開始
exec zsh

# または設定を再読み込み
source ~/.zshrc
```

#### fzfが動作しない場合
```bash
# fzfのシェル統合を再インストール
/opt/homebrew/opt/fzf/install --key-bindings --completion --no-update-rc
```

#### 履歴が保存されない場合
```bash
# 履歴ファイルの権限を確認
ls -la ~/.zsh_history

# 権限が正しくない場合は修正
chmod 600 ~/.zsh_history
```

#### Gemini検索が動作しない場合
```bash
# Gemini CLIがインストールされているか確認
which gemini

# インストールされていない場合
npm install -g @google/gemini-cli

# 認証状態を確認
gemini auth status

# 認証が必要な場合
gemini auth login
```

### パフォーマンスの最適化

#### 起動が遅い場合
```bash
# PATH情報を確認
path_info

# 環境診断を実行
dotfiles-diag

# 起動時間の測定（.zshrcに追加）
# ファイルの最初に: zmodload zsh/zprof
# ファイルの最後に: zprof
```

#### tmuxの問題
```bash
# tmuxサーバーがハングした場合
tmux kill-server

# セッション一覧が表示されない場合
tmux list-sessions

# キーバインドが効かない場合
tmux show-options -g | grep prefix
tmux list-keys | grep split

# 設定を再読み込み
# tmux内で: Ctrl+a r
```

### カスタマイズ

#### マシン固有の設定追加
```bash
# ~/.zshrc.local にマシン固有の設定を追加
echo "export CUSTOM_VAR=value" >> ~/.zshrc.local

# ~/.env.local にプロジェクト固有の環境変数を追加
echo "export API_KEY=your-key" >> ~/.env.local
```

#### 新しいエイリアスの追加
```bash
# ~/.zshrc.local にカスタムエイリアスを追加
echo "alias myalias='my command'" >> ~/.zshrc.local
```

## バックアップとリストア

インストールスクリプトは既存のファイルを`.backup.YYYYMMDD_HHMMSS`形式で自動バックアップします。

元の設定に戻したい場合：

```bash
# バックアップファイルを確認
ls -la ~/*.backup.*

# リストア
mv ~/.zshrc.backup.20240101_120000 ~/.zshrc
```

バックアップファイルの削除：

```bash
# インストール時に削除
./install.sh --clean-backup

# 手動で削除
make clean
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

# Claude MCP設定（APIトークン含む）
config/claude/claude_desktop_config.json.local
```

### ⚠️ 注意事項
- **機密情報は絶対にコミットしない**
- **新しい設定ファイルを追加する際は機密情報をチェック**
- **`.env.local`、`*.local` ファイルは `.gitignore` で除外済み**

## 🎓 学習リソース

### さらに詳しく学ぶには
- [fzf Wiki](https://github.com/junegunn/fzf/wiki) - fzfの高度な使い方
- [eza GitHub](https://github.com/eza-community/eza) - ezaの全機能
- [bat GitHub](https://github.com/sharkdp/bat) - batのカスタマイズ
- [ripgrep User Guide](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md) - ripgrepの詳細ガイド

### ヒント
- **Tab補完**: コマンドやファイル名は積極的にTabで補完する
- **履歴活用**: Ctrl+Rを使って過去のコマンドを効率的に再利用
- **エイリアス確認**: `alias` コマンドで現在のエイリアス一覧を確認
- **ヘルプ表示**: 各ツールは `--help` オプションで詳細な使い方を確認可能

---

このガイドを参考に、効率的な開発環境をお楽しみください！ 🚀