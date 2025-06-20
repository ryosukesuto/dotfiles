# 🚀 dotfiles オンボーディングガイド

このガイドでは、dotfilesに含まれる便利なツールやエイリアス、関数の使い方を説明します。

## 📋 目次

1. [基本的なエイリアス](#基本的なエイリアス)
2. [モダンツール](#モダンツール)
3. [Git関連](#git関連)
4. [便利な関数](#便利な関数)
5. [キーバインド](#キーバインド)
6. [プロンプト機能](#プロンプト機能)
7. [SSH管理ツール](#ssh管理ツール)
8. [開発ツール](#開発ツール)
9. [トラブルシューティング](#トラブルシューティング)

---

## 基本的なエイリアス

### ディレクトリ移動
```bash
..          # cd ..
...         # cd ../..
....        # cd ../../..

# 自動的にpushdされるため、以下も使用可能
cd -        # 前のディレクトリに戻る
dirs        # ディレクトリスタックを表示
```

### 安全なファイル操作
```bash
rm file     # rm -i file (削除前に確認)
cp file     # cp -i file (上書き前に確認)
mv file     # mv -i file (上書き前に確認)
```

### その他便利なエイリアス
```bash
h           # history (履歴表示)
j           # jobs -l (ジョブ一覧)
reload      # source ~/.zshrc (設定再読み込み)
path        # PATHを改行区切りで表示
```

---

## モダンツール

dotfilesは従来のコマンドをより高機能なモダンツールに自動的に置き換えます：

### 📁 eza（ls の代替）
```bash
ls          # eza --icons (アイコン付きリスト)
ll          # eza -l --icons (詳細リスト)
la          # eza -la --icons (隠しファイル含む詳細リスト)
tree        # eza --tree --icons (ツリー表示)
lt          # eza --tree --level=2 --icons (2階層ツリー)
```

### 📖 bat（cat の代替）
```bash
cat file.js    # シンタックスハイライト付きで表示
less file.py   # batをページャーとして使用
man command    # マニュアルもシンタックスハイライト付き
```

### 🔍 ripgrep（grep の代替）
```bash
grep "pattern" .        # rg "pattern" . (高速検索)
rg "function" --type js # JavaScriptファイルのみ検索
rg "TODO" -A 3 -B 1     # 前後の行も表示
```

### 🔍 fd（find の代替）
```bash
find . -name "*.js"     # fd "\.js$" . (高速ファイル検索)
fd config               # 名前にconfigを含むファイル検索
fd -t f -e js           # JavaScriptファイルのみ検索
```

---

## Git関連

### 基本的なGitエイリアス
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

### 高度なGitエイリアス
```bash
gl          # git log --oneline --graph --decorate
gla         # git log --oneline --graph --decorate --all
git lg      # 美しいグラフ付きログ
git undo    # 直前のコミットを取り消し
git amend   # 直前のコミットを修正（メッセージ変更なし）
git unstage # ステージングを取り消し
```

### Git便利関数
```bash
gacp "commit message"   # add . && commit && push を一度に実行
```

---

## 便利な関数

### ディレクトリ操作
```bash
mkcd dirname            # ディレクトリ作成と移動を同時実行
```

### ファイル展開
```bash
extract file.zip        # 自動的に適切な展開コマンドを選択
extract file.tar.gz     # .zip, .tar.gz, .rar, .7z など対応
```

### サイズ確認
```bash
sizeof file             # ファイル/ディレクトリサイズを表示
sizeof .                # dustがあれば使用、なければdu -sh
```

### ネットワーク
```bash
port 3000               # ポート3000で実行中のプロセスを表示
ping google.com         # 5回pingして終了
ports                   # 開いているポートを表示
```

### macOS専用
```bash
copy                    # pbcopy (クリップボードにコピー)
paste                   # pbpaste (クリップボードから貼り付け)
```

---

## キーバインド

### fzf統合
- **Ctrl+R**: 履歴をファジー検索
- **Ctrl+T**: ファイルをファジー検索してコマンドラインに挿入
- **Alt+C**: ディレクトリをファジー検索して移動

### カスタムキーバインド
- **Ctrl+]**: ghqリポジトリをファジー検索して移動

### tmux操作（Ctrl+a がプレフィックス）
- **Ctrl+a |**: 縦分割（パイプ記号）
- **Ctrl+a -**: 横分割（ハイフン）
- **Ctrl+a h/j/k/l**: ペイン間移動（Vim風：左/下/上/右）
- **Ctrl+a r**: 設定再読み込み
- **Ctrl+a d**: セッションからデタッチ
- **Ctrl+a c**: 新しいウィンドウ作成

### 使用例
```bash
# Ctrl+R を押すと履歴検索画面が開く
# 「docker」と入力すると、dockerを含むコマンド履歴が絞り込まれる

# Ctrl+T を押すとファイル検索画面が開く
# ファイル名を入力すると、そのファイルパスがコマンドラインに挿入される

# Ctrl+] を押すとghqで管理されているリポジトリ一覧が表示される
# リポジトリを選択すると、そのディレクトリに移動

# tmux操作例
# 1. 新しいセッションを開始
tmux

# 2. ペイン分割
# Ctrl+a | で縦分割 → 左右にペイン
# Ctrl+a - で横分割 → 上下にペイン

# 3. ペイン間移動（Vim風）
# Ctrl+a h で左へ、j で下へ、k で上へ、l で右へ

# 4. セッションからデタッチ（セッションは維持される）
# Ctrl+a d

# 5. セッションに再アタッチ
ta
```

---

## プロンプト機能

プロンプトは現在の状態を視覚的に表示します：

### 基本構成
```
username@hostname ~/current/directory (git-branch✓) (py:3.9.0) (node:18.0.0)
❯ 
```

### 表示される情報
- **ユーザー名@ホスト名**: 現在のユーザーとマシン
- **カレントディレクトリ**: 現在の作業ディレクトリ
- **Gitブランチ状態**: 
  - `(branch✓)`: クリーンな状態
  - `(branch✗)`: 変更あり
- **Python環境**: `(py:バージョン)` または `(仮想環境名)`
- **Node.js環境**: `(node:バージョン)` (package.jsonがある場合)
- **実行時間**: 5秒以上のコマンドは実行時間を表示

### プロンプトの切り替え
```bash
prompt_minimal          # シンプルなプロンプトに変更
prompt_full             # フル機能プロンプトに変更
```

---

## SSH管理ツール

### SSH設定の特徴
- **接続高速化**: ControlMaster で接続再利用
- **セキュリティ強化**: 鍵認証のみ、パスワード認証無効
- **便利な設定**: ホスト別設定、踏み台サーバー対応

### SSH便利エイリアス
```bash
ssh-utils               # SSH管理ツールメニュー表示
ssh-list               # 設定済みホスト一覧
ssh-test hostname      # ホストへの接続テスト
ssh-keygen-ed25519     # ED25519鍵の生成
ssh-security           # セキュリティチェック
```

### SSH管理ツールの詳細機能
```bash
# ホスト一覧表示
ssh-utils list-hosts

# 接続テスト
ssh-utils test-connection github.com
ssh-utils test-connection production

# SSH鍵生成（推奨: ED25519）
ssh-utils generate-key ed25519 mykey
ssh-utils generate-key rsa myoldkey

# ホスト設定を追加
ssh-utils add-host myserver server.example.com deploy ~/.ssh/id_ed25519

# SSHキーをバックアップ
ssh-utils backup-keys

# セキュリティチェック
ssh-utils check-security

# 古い接続ソケットをクリーンアップ
ssh-utils cleanup
```

### SSH設定例
```bash
# 既存のホストに接続
ssh github.com          # Git操作
ssh production          # 本番サーバー
ssh staging             # ステージングサーバー

# 踏み台サーバー経由の接続
ssh internal-web        # 踏み台経由で内部サーバーへ

# ポートフォワーディング
ssh tunnel-db           # データベース接続用トンネル

# SOCKS プロキシ
ssh socks-proxy         # プロキシサーバー接続
```

### セキュリティのベストプラクティス
- **ED25519鍵**: RSAより高速で安全な暗号化方式
- **鍵のパスフレーズ**: 必ず設定する
- **定期的な鍵ローテーション**: 古い鍵は無効化
- **権限設定**: 秘密鍵は600、設定ファイルは644

---

## 開発ツール

### Docker
```bash
d           # docker
dc          # docker-compose
dps         # docker ps
dimg        # docker images
```

### Kubernetes
```bash
k           # kubectl
kgp         # kubectl get pods
kgs         # kubectl get services
kgd         # kubectl get deployments
```

### tmux（ターミナルマルチプレクサ）
```bash
t           # tmux (新しいセッション開始)
ta          # tmux attach (セッションにアタッチ)
tl          # tmux list-sessions (セッション一覧)
tn          # tmux new-session (新しいセッション作成)
tk          # tmux kill-session (セッション削除)
```

### Python環境
```bash
# pyenvは遅延初期化されるため、初回実行時のみ少し時間がかかります
pyenv versions         # 利用可能なPythonバージョン
python --version       # 現在のPythonバージョン
```

### 環境変数
```bash
# プロジェクト固有の環境変数は ~/.env.local で管理
echo $DBT_PROJECT_ID   # DBTプロジェクトID
echo $DBT_AWS_ENV      # DBT環境設定
```

---

## トラブルシューティング

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

### パフォーマンスの最適化

#### 起動が遅い場合
```bash
# どの設定ファイルが重いか確認
zsh -xvs 2>&1 | head -20

# 補完キャッシュをクリア
rm ~/.zcompdump*
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

---

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