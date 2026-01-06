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
  ghostty/         - Ghosttyターミナル設定
  git/             - Git設定
  gh/              - GitHub CLI設定
  tmux/            - tmux設定
  vim/             - Vim設定
  ssh/             - SSH設定
  aws/             - AWSテンプレート
  mise/            - mise設定
bin/           - カスタムスクリプト
```

## 主要ツール

- ターミナル: Ghostty (UDEV Gothic 35NF)
- シェル: Zsh + ghq/fzf (Ctrl+])
- バージョン管理: mise
- AI: Claude Code, Codex CLI
- クラウド: AWS (SSM Session Manager)

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
