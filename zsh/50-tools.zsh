#!/usr/bin/env zsh
# ============================================================================
# 50-tools.zsh - 開発ツールの初期化
# ============================================================================
# このファイルはmiseなどの開発ツールを初期化します。

# 補完キャッシュディレクトリ
[[ -d ~/.zsh/cache ]] || mkdir -p ~/.zsh/cache

# GitHub API レート制限回避 (gh/mise の lazy token wrapper) は .zshenv で定義済み。
# 非対話 subprocess (Claude Code の Bash tool 等) でも有効にするため移設した。

# mise初期化（shims方式 - envセクション未使用のためhook不要）
if (( $+commands[mise] )); then
  eval "$(command mise activate zsh --shims)"
fi

# direnv初期化（環境変数の自動切替）
if (( $+commands[direnv] )); then
  # bw-fetch 経由で Bitwarden を unlock する .envrc があるため、警告閾値を延長
  export DIRENV_WARN_TIMEOUT=30s
  eval "$(direnv hook zsh)"
fi

# Claude Code
if (( $+commands[claude] )); then
  alias claude='claude --model "claude-opus-4-7[1m]" --dangerously-skip-permissions'
  _claude_ctx="$HOME/.claude/contexts"
  alias claude-review='claude --system-prompt "$(cat "$_claude_ctx/review.md" 2>/dev/null)"'
  alias claude-research='claude --system-prompt "$(cat "$_claude_ctx/research.md" 2>/dev/null)"'
  alias claude-incident='claude --mcp-config ~/.claude/mcp-incident.json --system-prompt "$(cat "$_claude_ctx/incident.md" 2>/dev/null)"'
fi

