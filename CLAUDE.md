# CLAUDE.md

Claude Code用のリポジトリガイダンス。

## リポジトリ概要

個人用dotfilesリポジトリ。Zsh、Git、SSH、tmux、Vim、AWS CLI、GitHub CLIなどの設定ファイルを管理。

## 構成

```
zsh/           - Zsh設定（Claude Code実行環境として最適化）
  00-core.zsh      - コアシェル設定
  20-path.zsh      - PATH管理
  50-tools.zsh     - mise/direnv初期化
  60-prompt.zsh    - プロンプト設定（ENV/AWS警告）
  90-local.zsh     - ローカル設定
config/        - アプリ設定
  claude/          - Claude Code設定
  codex/           - Codex CLI設定
  direnv/          - direnv設定（環境変数自動切替）
  fzf/             - fzf設定
  ghostty/         - Ghosttyターミナル設定
  git/             - Git設定
  gh/              - GitHub CLI設定
  tmux/            - tmux設定
  vim/             - Vim設定
  ssh/             - SSH設定
  mise/            - mise設定
bin/           - カスタムスクリプト
  ctx-iac            - PR情報/planコメント収集（AI連携用）
  claude-commit-log  - コミットログ整形
  claude-times-post  - 勤怠投稿
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

### Claude Codeでのworktree操作

`EnterWorktree` / `ExitWorktree` ツールでworktreeの切替が可能。
ブランチ作業時は `EnterWorktree` でworktreeに入り、完了後は `ExitWorktree` で戻る。

```
EnterWorktree → .worktrees/feature/xxx で作業 → ExitWorktree で元のディレクトリに復帰
```

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
