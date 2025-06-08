# PATH管理の関数
path_prepend() {
  for arg in "$@"; do
    if [[ -d "$arg" ]] && [[ ":$PATH:" != *":$arg:"* ]]; then
      PATH="$arg:$PATH"
    fi
  done
}

path_append() {
  for arg in "$@"; do
    if [[ -d "$arg" ]] && [[ ":$PATH:" != *":$arg:"* ]]; then
      PATH="$PATH:$arg"
    fi
  done
}

# Go設定
export GOPATH="$HOME"
path_append "$GOPATH/bin"

# Terraform (tfenv)
path_append "$HOME/.tfenv/bin"

# Python (pyenv)
export PYENV_ROOT="$HOME/.pyenv"
path_prepend "$PYENV_ROOT/bin"

# ローカルbin
path_prepend "$HOME/.local/bin"

# Homebrew bin (Apple Silicon Mac対応)
if [[ -d "/opt/homebrew/bin" ]]; then
  path_prepend "/opt/homebrew/bin" "/opt/homebrew/sbin"
elif [[ -d "/usr/local/bin" ]]; then
  path_prepend "/usr/local/bin" "/usr/local/sbin"
fi

# エディタ設定
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"

# 言語設定
export LANG="${LANG:-ja_JP.UTF-8}"
export LC_ALL="${LC_ALL:-ja_JP.UTF-8}"

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"