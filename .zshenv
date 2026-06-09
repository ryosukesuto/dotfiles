#!/usr/bin/env zsh
# .zshenv - すべての zsh 起動で読まれる（interactive/login 問わず）
#
# 非対話 zsh subprocess (Claude Code の Bash tool 等) でも gh / mise が
# GITHUB_TOKEN 経由で認証できるよう、wrapper をここで定義する。
# .zshrc は interactive shell でのみ読まれるため、subprocess には届かない。
#
# 重い処理は書かない。lazy 評価の wrapper 定義のみ。

if (( $+commands[gh] )) && [[ -z "$GITHUB_TOKEN" ]]; then
  export GITHUB_TOKEN
  _gh_ensure_token() {
    if [[ -z "$GITHUB_TOKEN" ]]; then
      # wrapper 再帰を避けるため command 経由で素の gh を呼ぶ
      GITHUB_TOKEN="$(command gh auth token 2>/dev/null)"
    fi
  }
  gh() {
    _gh_ensure_token
    unfunction gh 2>/dev/null
    command gh "$@"
  }
  mise() {
    _gh_ensure_token
    unfunction mise 2>/dev/null
    command mise "$@"
  }
fi
