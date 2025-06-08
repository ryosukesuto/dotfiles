# Terraform補完
if command -v terraform &> /dev/null; then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C $(which terraform) terraform
fi

# pyenv遅延初期化（パフォーマンス向上）
if command -v pyenv &> /dev/null; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  
  # pyenvコマンドが初回実行時に初期化
  pyenv() {
    unfunction pyenv
    eval "$(command pyenv init --path)"
    eval "$(command pyenv init -)"
    pyenv "$@"
  }
  
  # python, pip, python3コマンドでも初期化
  python() {
    unfunction python python3 pip pip3 2>/dev/null
    eval "$(command pyenv init --path)"
    eval "$(command pyenv init -)"
    python "$@"
  }
  
  python3() {
    unfunction python python3 pip pip3 2>/dev/null
    eval "$(command pyenv init --path)"
    eval "$(command pyenv init -)"
    python3 "$@"
  }
  
  pip() {
    unfunction python python3 pip pip3 2>/dev/null
    eval "$(command pyenv init --path)"
    eval "$(command pyenv init -)"
    pip "$@"
  }
  
  pip3() {
    unfunction python python3 pip pip3 2>/dev/null
    eval "$(command pyenv init --path)"
    eval "$(command pyenv init -)"
    pip3 "$@"
  }
fi

# rbenv（Rubyがある場合）
if command -v rbenv &> /dev/null; then
  rbenv() {
    unfunction rbenv
    eval "$(command rbenv init -)"
    rbenv "$@"
  }
fi

# nodenv（Node.jsがある場合）
if command -v nodenv &> /dev/null; then
  nodenv() {
    unfunction nodenv
    eval "$(command nodenv init -)"
    nodenv "$@"
  }
fi

# direnv（ディレクトリ固有の環境変数）
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# GitHub CLI補完
if command -v gh &> /dev/null; then
  eval "$(gh completion -s zsh)"
fi

# Docker補完（Docker Desktopがインストールされている場合）
if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion
fi

if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion
fi