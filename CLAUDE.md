# CLAUDE.md

Claude Code用のリポジトリガイダンス。

## リポジトリ概要

個人用dotfilesリポジトリ。Zsh、Git、SSH、tmux、Vim、AWS CLI、GitHub CLIなどの設定ファイルを管理。

## 構成

```
zsh/           - Zsh設定（番号順に読み込み）
  00-core.zsh      - コアシェル設定
  10-completion.zsh - 補完設定
  20-path.zsh      - PATH管理
  30-aliases.zsh   - エイリアス定義
  40-functions.zsh - シェル関数
  50-tools.zsh     - mise初期化
  60-prompt.zsh    - プロンプト設定
  90-local.zsh     - ローカル設定
  functions/       - 遅延読み込み関数
config/        - アプリ設定
  claude/          - Claude Code設定
  codex/           - Codex CLI設定
  direnv/          - direnv設定（環境変数自動切替）
  ghostty/         - Ghosttyターミナル設定
  git/             - Git設定
  gh/              - GitHub CLI設定
  tmux/            - tmux設定
  vim/             - Vim設定
  ssh/             - SSH設定
  aws/             - AWSテンプレート
  mise/            - mise設定
bin/           - カスタムスクリプト
  ctx-iac          - PR情報/planコメント収集（AI連携用）
  tmux-iac         - IaC用3ペインレイアウト起動
  th               - Obsidianデイリーノート記録
```

## 主要ツール

- ターミナル: Ghostty (UDEV Gothic 35NF)
- シェル: Zsh + ghq/fzf (Ctrl+]) + git-wt/fzf (Ctrl+\)
- バージョン管理: mise
- AI: Claude Code, Codex CLI
- クラウド: AWS (SSM Session Manager)

## 開発フロー（ghq + git worktree）

リポジトリ管理はghq、ブランチ作業はgit worktreeで分離。

### 基本フロー
```bash
# 1. リポジトリをclone（ghq）
ghq get github.com/org/repo
cd $(ghq root)/github.com/org/repo

# 2. 機能開発時はworktreeを作成（git-wt）
git-wt add feature/xxx    # .worktrees/feature/xxx に作成
cd .worktrees/feature/xxx

# 3. 作業完了後はworktreeを削除
git-wt remove feature/xxx
```

### キーバインド
- `Ctrl+]`: ghqリポジトリ選択（fzf）
- `Ctrl+\`: worktree選択（fzf）

### エイリアス
- `wt`: git-wt
- `wta`: git-wt add（worktree作成）
- `wtl`: git-wt list（一覧）
- `wtr`: git-wt remove（削除）

### 設定
gitconfigで `.worktrees` をbasedirに設定済み。

## IaC運用

### 環境切替（direnv）

```bash
# IaCリポジトリで.envrc作成
cp ~/gh/ryosukesuto/dotfiles/config/direnv/envrc-iac.template .envrc
direnv allow

# または簡易版
echo 'layout_iac dev' > .envrc
echo 'use_aws_profile my-profile' >> .envrc
direnv allow
```

プロンプトにENV/AWS_PROFILE/GCP_PROJECT自動表示（prdは赤警告）

### PR情報収集（ctx-iac）

```bash
ctx-iac              # 現在ブランチのPR情報
ctx-iac 123          # PR #123
ctx-iac -c | pbcopy  # AI用にコピー
ctx-iac -p           # planコメントのみ
ctx-iac -l           # ローカルlintも実行
```

### tmuxレイアウト

```bash
tmux-iac              # 3ペインセッション起動
# または既存セッション内で Ctrl-a I
```

レイアウト: 左=作業、右上=PR監視、右下=Lint

## タスク

1. インストール: `./install.sh`
2. 更新: リポジトリ変更 → シンボリックリンク経由で即反映
3. ローカル設定: `.local`ファイル使用（gitignore済み）
4. AWS: `aws sso login --profile <name>`

## セキュリティ

- 認証情報はコミットしない
- テンプレートファイル使用（aws/）
- 機密設定は`.local`ファイルへ

## 重要

要求されたことだけを行う。不要なファイル作成禁止。
