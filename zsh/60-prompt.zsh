#!/usr/bin/env zsh
# プロンプト設定（vcs_info使用で高速化）

autoload -Uz colors && colors
autoload -Uz vcs_info
setopt PROMPT_SUBST

# vcs_info設定
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' formats ' %F{green}(%b%u%c)%f'
zstyle ':vcs_info:*' actionformats ' %F{green}(%b|%a%u%c)%f'
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr '+'
zstyle ':vcs_info:*' unstagedstr '*'

# 環境情報を生成（事故防止用）
_prompt_env_info() {
  local info=()

  # ENV（prd/prodは赤で警告）
  if [[ -n "$ENV" ]]; then
    if [[ "$ENV" =~ ^(prd|prod|production)$ ]]; then
      info+=("%F{red}ENV:${ENV}%f")
    else
      info+=("%F{blue}ENV:${ENV}%f")
    fi
  fi

  # AWS_PROFILE
  if [[ -n "$AWS_PROFILE" ]]; then
    info+=("%F{yellow}AWS:${AWS_PROFILE}%f")
  fi

  # GCP_PROJECT
  if [[ -n "$GOOGLE_CLOUD_PROJECT" ]]; then
    info+=("%F{cyan}GCP:${GOOGLE_CLOUD_PROJECT}%f")
  elif [[ -n "$GCP_PROJECT" ]]; then
    info+=("%F{cyan}GCP:${GCP_PROJECT}%f")
  fi

  # 情報があれば表示
  if [[ ${#info[@]} -gt 0 ]]; then
    echo "[${(j: :)info}] "
  fi
}

# precmdでvcs_infoを更新（プロンプト表示前に1回だけ実行）
precmd() { vcs_info }

# プロンプト設定
PROMPT='$(_prompt_env_info)%F{cyan}%~%f${vcs_info_msg_0_}
%F{yellow}>%f '
RPROMPT='%F{8}%T%f'
