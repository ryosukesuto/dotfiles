#!/usr/bin/env zsh
# ============================================================================
# 50-tools.zsh - 開発ツールの初期化
# ============================================================================
# このファイルはmiseなどの開発ツールを初期化します。

# 補完キャッシュディレクトリ
[[ -d ~/.zsh/cache ]] || mkdir -p ~/.zsh/cache

# mise初期化（shimsはPATHにあるがhooks用にactivate）
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

# direnv初期化（環境変数の自動切替）
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

# Terraform補完
if (( $+commands[terraform] )); then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C "$(whence -p terraform)" terraform
fi

# GitHub CLI補完（キャッシュ付き）
if (( $+commands[gh] )); then
  local gh_cache=~/.zsh/cache/gh_completion.zsh
  local gh_bin="$(whence -p gh)"
  if [[ ! -f "$gh_cache" ]] || [[ "$gh_bin" -nt "$gh_cache" ]]; then
    gh completion -s zsh > "$gh_cache" 2>/dev/null
  fi
  [[ -f "$gh_cache" ]] && source "$gh_cache"
fi

# Docker補完（ファイルベースなので高速）
[[ -f /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion ]] && \
  source /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion
[[ -f /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion ]] && \
  source /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion