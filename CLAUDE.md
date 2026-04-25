# CLAUDE.md

Claude Code用のリポジトリガイダンス。

## リポジトリ概要

個人用dotfilesリポジトリ。Zsh、Git、SSH、tmux、Vim、AWS CLI、GitHub CLIなどの設定ファイルを管理。

## 構成

```
zsh/           - Zsh設定（Claude Code実行環境として最適化）
  00-core.zsh      - コアシェル設定
  20-path.zsh      - PATH管理（PNPM_HOME含む）
  40-functions.zsh - カスタム関数
  50-tools.zsh     - mise/direnv初期化
  60-prompt.zsh    - プロンプト設定（ENV/AWS警告）
  90-local.zsh     - ローカル設定
config/        - アプリ設定
  claude/          - Claude Code設定
  codex/           - Codex CLI設定
  direnv/          - direnv設定（環境変数自動切替）
  fzf/             - fzf設定
  ghostty/         - Ghosttyターミナル設定
  lazygit/         - lazygit設定（UI・theme・delta pager）
  git/             - Git設定
  gh/              - GitHub CLI設定
  mise/            - mise設定（node, uv等）
  npm/             - npmrc（pnpmハードニング設定）
  ssh/             - SSH設定
  tmux/            - tmux設定
  vim/             - Vim設定
bin/           - カスタムスクリプト
  ctx-iac              - PR情報/planコメント収集（AI連携用）
  claude-commit-log    - コミットログ整形
  claude-times-post    - 勤怠投稿
  claude-guard-main-edit - mainブランチ編集ガード（PreToolUse hook）
  claude-suggest-compact - コンパクト提案（PreToolUse hook）
  claude-pre-compact   - コンパクト前処理（PreCompact hook）
  claude-session-end   - セッション終了処理（Stop hook）
  claude-review-coverage - ghq配下のリポでsetup-ci-review適用状況を集計（md/json）
  cmux-quad            - cmux 4分割レイアウト
  cmux-lazygit         - cmuxで現在ペインを分割してlazygit起動
```

## 主要ツール

- ターミナル: Ghostty (UDEV Gothic 35NF)
- シェル: Zsh + ghq/fzf (Ctrl+]) + git-wt/fzf (Ctrl+\)
- バージョン管理: mise
- AI: Claude Code, Codex CLI
- クラウド: AWS (SSM Session Manager)

## 開発フロー（ghq + git worktree）

リポジトリ管理はghq、ブランチ作業はgit worktreeで分離。

### worktree必須ルール

ブランチ作業は必ずworktreeで行う。`git checkout -b` は使わない。

- 理由: 複数タスクを並行実行するため、作業ディレクトリの独立性が必要
- mainへの直接コミットはpre-commitフックでブロック済み（`wt.allowDirectCommit` でopt-out可能）
- Claude Codeでの並列作業は `isolation: "worktree"` のsubagentも活用する

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
- gitconfigで `.worktrees` をbasedirに設定済み
- `git/hooks/pre-commit` でmain/masterへの直接コミットをブロック

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

1. インストール: `./install.sh`（`--force` で確認スキップ、`--dry-run` で確認のみ、`--brew` でBrewfile実行）
2. 更新: リポジトリ変更 → シンボリックリンク経由で即反映
3. ローカル設定: `.local`ファイル使用（gitignore済み、dotfiles-privateで管理）
4. AWS: `aws sso login --profile <name>`

## セキュリティ

- 認証情報はコミットしない
- テンプレートファイル使用（aws/）
- 機密設定は`.local`ファイルへ（グローバル設定のセキュリティセクション参照）

## 重要

要求されたことだけを行う。不要なファイル作成禁止。
