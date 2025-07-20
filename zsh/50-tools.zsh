#!/usr/bin/env zsh
# ============================================================================
# 50-tools.zsh - 開発ツールの遅延初期化
# ============================================================================
# このファイルはpyenv、rbenv、Terraformなどの開発ツールを遅延初期化します。
# 実際にコマンドが使用されるまで初期化を遅延させることで起動時間を短縮します。

# 遅延読み込み用の初期化フラグ
typeset -g _DOTFILES_PYENV_INIT_DONE=0
typeset -g _DOTFILES_RBENV_INIT_DONE=0

# pyenv遅延初期化関数
_dotfiles_init_pyenv() {
  [[ $_DOTFILES_PYENV_INIT_DONE -eq 1 ]] && return
  _DOTFILES_PYENV_INIT_DONE=1

  if command -v pyenv &> /dev/null; then
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
  fi
}

# rbenv遅延初期化関数
_dotfiles_init_rbenv() {
  [[ $_DOTFILES_RBENV_INIT_DONE -eq 1 ]] && return
  _DOTFILES_RBENV_INIT_DONE=1

  if command -v rbenv &> /dev/null; then
    eval "$(rbenv init -)"
  fi
}

# aliasベースの遅延読み込み設定
if command -v pyenv &> /dev/null; then
  alias python='_dotfiles_init_pyenv && unalias python && python'
  alias python3='_dotfiles_init_pyenv && unalias python3 && python3'
  alias pip='_dotfiles_init_pyenv && unalias pip && pip'
  alias pip3='_dotfiles_init_pyenv && unalias pip3 && pip3'
  alias pyenv='_dotfiles_init_pyenv && unalias pyenv && pyenv'
fi

if command -v rbenv &> /dev/null; then
  alias ruby='_dotfiles_init_rbenv && unalias ruby && ruby'
  alias gem='_dotfiles_init_rbenv && unalias gem && gem'
  alias bundle='_dotfiles_init_rbenv && unalias bundle && bundle'
  alias rbenv='_dotfiles_init_rbenv && unalias rbenv && rbenv'
fi


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