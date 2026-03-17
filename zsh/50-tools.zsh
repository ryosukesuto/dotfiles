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

# Terraform補完（遅延ロード - 初回TAB時にセットアップ）
if (( $+commands[terraform] )); then
  terraform() {
    unfunction terraform 2>/dev/null
    autoload -U +X bashcompinit && bashcompinit
    complete -o nospace -C "$(whence -p terraform)" terraform
    command terraform "$@"
  }
fi

# GitHub CLI補完（遅延ロード - 初回TAB時にキャッシュ生成+読み込み）
if (( $+commands[gh] )); then
  _gh_lazy_completion() {
    local gh_cache=~/.zsh/cache/gh_completion.zsh
    local gh_bin="$(whence -p gh)"
    if [[ ! -f "$gh_cache" ]] || [[ "$gh_bin" -nt "$gh_cache" ]]; then
      command gh completion -s zsh > "$gh_cache" 2>/dev/null
    fi
    [[ -f "$gh_cache" ]] && source "$gh_cache"
    compdef -d gh
    _gh "$@"
  }
  compdef _gh_lazy_completion gh
fi

# Docker補完（ファイルベースなので高速）
[[ -f /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion ]] && \
  source /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion
[[ -f /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion ]] && \
  source /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion