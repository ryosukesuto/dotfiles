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
# 既存のフックを削除してから追加（重複防止）
add-zsh-hook -d preexec _tool_preexec 2>/dev/null
add-zsh-hook preexec _tool_preexec

# 即座に必要なツール
# direnv（ディレクトリ固有の環境変数）- 遅延初期化
_init_direnv() {
  if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh)"
  fi
}

# 初回のcd時にdirenvを初期化
chpwd_functions=(${chpwd_functions[@]} "_init_direnv_once")
_init_direnv_once() {
  _init_direnv
  # 初期化後は関数を削除
  chpwd_functions=(${chpwd_functions[@]:#_init_direnv_once})
}

# Terraform補完（シンプルな設定）
if command -v terraform &> /dev/null; then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C $(which terraform) terraform
fi

# GitHub CLI補完（シンプルな設定）
if command -v gh &> /dev/null; then
  eval "$(gh completion -s zsh 2>/dev/null)"
fi

# Docker補完（即座に読み込み - ファイルベースなので高速）
if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion
fi

if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion
fi