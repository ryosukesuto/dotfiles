# Terraform補完
if command -v terraform &> /dev/null; then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C $(which terraform) terraform
fi

# pyenv設定（シンプル版）
if command -v pyenv &> /dev/null; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  # 起動時に初期化（安全性重視）
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
fi

# rbenv（Rubyがある場合）
if command -v rbenv &> /dev/null; then
  eval "$(rbenv init -)"
fi

# nodenv（Node.jsがある場合）
if command -v nodenv &> /dev/null; then
  eval "$(nodenv init -)"
fi

# direnv（ディレクトリ固有の環境変数）
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# GitHub CLI補完（タイムアウト付き）
if command -v gh &> /dev/null; then
  # 5秒でタイムアウト
  if timeout 5s gh completion -s zsh 2>/dev/null; then
    eval "$(gh completion -s zsh)"
  fi
fi

# Docker補完（Docker Desktopがインストールされている場合）
if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion
fi

if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion
fi