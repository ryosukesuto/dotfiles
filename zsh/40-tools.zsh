# 遅延読み込み用の初期化フラグ
typeset -g _tools_init_done=0

# 遅延読み込み関数
_init_tools_lazy() {
  [[ $_tools_init_done -eq 1 ]] && return
  _tools_init_done=1

  # pyenv設定（遅延読み込み）
  if command -v pyenv &> /dev/null; then
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
  fi

  # rbenv（遅延読み込み）
  if command -v rbenv &> /dev/null; then
    eval "$(rbenv init -)"
  fi

  # nodenv（遅延読み込み）
  if command -v nodenv &> /dev/null; then
    eval "$(nodenv init -)"
  fi
}

# ツール特定のコマンドが実行される時に初期化
_lazy_load_version_managers() {
  local cmd="$1"
  case "$cmd" in
    python*|pip*|pyenv*)
      if command -v pyenv &> /dev/null && [[ $_tools_init_done -eq 0 ]]; then
        _init_tools_lazy
      fi
      ;;
    ruby*|gem*|bundle*|rbenv*)
      if command -v rbenv &> /dev/null && [[ $_tools_init_done -eq 0 ]]; then
        _init_tools_lazy
      fi
      ;;
    node*|npm*|yarn*|nodenv*)
      if command -v nodenv &> /dev/null && [[ $_tools_init_done -eq 0 ]]; then
        _init_tools_lazy
      fi
      ;;
  esac
}

# preexecフックに追加（既存のpreexecと競合しないよう配慮）
_tool_preexec() {
  _lazy_load_version_managers "$1"
}

# preexecフックのリストに追加
autoload -Uz add-zsh-hook
add-zsh-hook preexec _tool_preexec

# 即座に必要なツール
# direnv（ディレクトリ固有の環境変数）- 即座に初期化が必要
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# Terraform補完（遅延読み込み）
_init_terraform_completion() {
  if command -v terraform &> /dev/null; then
    autoload -U +X bashcompinit && bashcompinit
    complete -o nospace -C $(which terraform) terraform
  fi
}

# terraform コマンドが初回実行される時に補完を初期化
terraform() {
  unfunction terraform
  _init_terraform_completion
  terraform "$@"
}

# GitHub CLI補完（遅延読み込み）
_init_gh_completion() {
  if command -v gh &> /dev/null; then
    # 5秒でタイムアウト
    if timeout 5s gh completion -s zsh &> /dev/null; then
      eval "$(gh completion -s zsh)"
    fi
  fi
}

# gh コマンドが初回実行される時に補完を初期化
gh() {
  unfunction gh
  _init_gh_completion
  gh "$@"
}

# Docker補完（即座に読み込み - ファイルベースなので高速）
if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion
fi

if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion
fi