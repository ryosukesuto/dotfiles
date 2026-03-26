#!/usr/bin/env zsh
# ============================================================================
# 50-tools.zsh - 開発ツールの初期化
# ============================================================================
# このファイルはmiseなどの開発ツールを初期化します。

# 補完キャッシュディレクトリ
[[ -d ~/.zsh/cache ]] || mkdir -p ~/.zsh/cache

# GitHub API レート制限回避（遅延評価 - gh/mise初回実行時にセット）
if (( $+commands[gh] )) && [[ -z "$GITHUB_TOKEN" ]]; then
  export GITHUB_TOKEN
  _gh_ensure_token() {
    if [[ -z "$GITHUB_TOKEN" ]]; then
      GITHUB_TOKEN="$(gh auth token 2>/dev/null)"
    fi
  }
  # gh実行前にトークンをセットするラッパ
  gh() {
    _gh_ensure_token
    unfunction gh 2>/dev/null
    command gh "$@"
  }
  # mise実行前にもトークンをセット
  mise() {
    _gh_ensure_token
    unfunction mise 2>/dev/null
    command mise "$@"
  }
fi

# mise初期化（shims方式 - envセクション未使用のためhook不要）
if (( $+commands[mise] )); then
  eval "$(command mise activate zsh --shims)"
fi

# direnv初期化（環境変数の自動切替）
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

# Claude Code
if (( $+commands[claude] )); then
  alias claude='claude --dangerously-skip-permissions'
  _claude_ctx="$HOME/.claude/contexts"
  alias claude-review='claude --system-prompt "$(cat "$_claude_ctx/review.md" 2>/dev/null)"'
  alias claude-research='claude --system-prompt "$(cat "$_claude_ctx/research.md" 2>/dev/null)"'
  alias claude-incident='claude --mcp-config ~/.claude/mcp-incident.json --system-prompt "$(cat "$_claude_ctx/incident.md" 2>/dev/null)"'
fi

