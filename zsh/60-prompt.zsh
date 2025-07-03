#!/usr/bin/env zsh
# ============================================================================
# 60-prompt.zsh - カスタムプロンプト設定
# ============================================================================
# このファイルはGit、Python、AWS、Terraform情報を表示するプロンプトを設定します。
# キャッシュシステムにより、プロンプト表示のパフォーマンスを最適化しています。

# 色の定義
autoload -U colors && colors

# キャッシュ変数の初期化
typeset -g _prompt_cache_dir=""
typeset -g _prompt_cache_git_branch=""
typeset -g _prompt_cache_git_status=""
typeset -g _prompt_cache_repo_name=""
typeset -g _prompt_cache_python_env=""
typeset -g _prompt_cache_aws_env=""
typeset -g _prompt_cache_terraform_env=""
typeset -g _prompt_cache_timestamp=0

# キャッシュの有効期限（秒）
typeset -g _prompt_cache_ttl=30

# キャッシュをクリアする関数
_prompt_clear_cache() {
  _prompt_cache_dir=""
  _prompt_cache_git_branch=""
  _prompt_cache_git_status=""
  _prompt_cache_repo_name=""
  _prompt_cache_python_env=""
  _prompt_cache_aws_env=""
  _prompt_cache_terraform_env=""
  _prompt_cache_timestamp=0
}

# キャッシュが有効かチェックする関数
_prompt_cache_valid() {
  local current_time=$(date +%s)
  local current_dir="$PWD"
  
  # ディレクトリが変わった場合やキャッシュが期限切れの場合は無効
  if [[ "$current_dir" != "$_prompt_cache_dir" ]] || 
     [[ $((current_time - _prompt_cache_timestamp)) -gt $_prompt_cache_ttl ]]; then
    return 1
  fi
  return 0
}

# リポジトリ名を表示する関数（キャッシュ対応）
repo_name() {
  if ! _prompt_cache_valid || [[ -z "$_prompt_cache_repo_name" ]]; then
    if git rev-parse --git-dir &> /dev/null; then
      local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
      if [[ -n $repo_root ]]; then
        _prompt_cache_repo_name=$(basename "$repo_root")
      else
        _prompt_cache_repo_name=""
      fi
    else
      _prompt_cache_repo_name=""
    fi
  fi
  echo "$_prompt_cache_repo_name"
}

# Git情報を表示する関数（キャッシュ対応）
git_prompt_info() {
  if ! _prompt_cache_valid || [[ -z "$_prompt_cache_git_branch" ]]; then
    if git rev-parse --git-dir &> /dev/null; then
      local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
      local git_status=""
      
      # 作業ディレクトリの状態をチェック
      if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        git_status=" %F{red}✗%f"
      else
        git_status=" %F{green}✓%f"
      fi
      
      _prompt_cache_git_branch=" %F{magenta}$branch%f$git_status"
    else
      _prompt_cache_git_branch=""
    fi
  fi
  echo "$_prompt_cache_git_branch"
}

# ディレクトリ表示の関数（リポジトリ内ではリポジトリ名のみ）
smart_pwd() {
  local repo_name_val=$(repo_name)
  if [[ -n $repo_name_val ]]; then
    # Gitリポジトリ内の場合はリポジトリ名のみ表示
    echo "$repo_name_val"
  else
    # Gitリポジトリ外では最後の2階層のみ表示
    local current_path="%~"
    # ホームディレクトリより深い場合は最後の2階層のみ
    if [[ $(pwd | grep -o '/' | wc -l) -gt 2 ]] && [[ $(pwd) != $HOME* ]]; then
      echo "$(basename $(dirname $(pwd)))/$(basename $(pwd))"
    else
      echo "$current_path"
    fi
  fi
}

# Python仮想環境を表示する関数（キャッシュ対応）
python_env_info() {
  if ! _prompt_cache_valid || [[ -z "$_prompt_cache_python_env" ]]; then
    if [[ -n "$VIRTUAL_ENV" ]]; then
      _prompt_cache_python_env=" %F{yellow}(🐍$(basename $VIRTUAL_ENV))%f"
    elif command -v pyenv &> /dev/null; then
      local pyenv_version=$(pyenv version-name 2>/dev/null)
      if [[ -n "$pyenv_version" && "$pyenv_version" != "system" ]]; then
        _prompt_cache_python_env=" %F{yellow}(🐍py:$pyenv_version)%f"
      else
        _prompt_cache_python_env=""
      fi
    else
      _prompt_cache_python_env=""
    fi
  fi
  echo "$_prompt_cache_python_env"
}


# AWS環境を表示する関数（キャッシュ対応）
aws_env_info() {
  if ! _prompt_cache_valid || [[ -z "$_prompt_cache_aws_env" ]]; then
    if [[ -n "$AWS_PROFILE" ]]; then
      _prompt_cache_aws_env=" %F{208}(☁️ aws:$AWS_PROFILE)%f"
    else
      _prompt_cache_aws_env=""
    fi
  fi
  echo "$_prompt_cache_aws_env"
}

# Terraform環境を表示する関数（キャッシュ対応）
terraform_env_info() {
  if ! _prompt_cache_valid || [[ -z "$_prompt_cache_terraform_env" ]]; then
    if [[ -f *.tf(#qN) ]] && command -v terraform &> /dev/null; then
      local workspace=$(terraform workspace show 2>/dev/null)
      if [[ -n "$workspace" && "$workspace" != "default" ]]; then
        _prompt_cache_terraform_env=" %F{magenta}(💠tf:$workspace)%f"
      else
        _prompt_cache_terraform_env=""
      fi
    else
      _prompt_cache_terraform_env=""
    fi
  fi
  echo "$_prompt_cache_terraform_env"
}


# 実行時間を測定する関数
preexec() {
  # macOSのdateコマンド対応（ナノ秒はサポートされていない）
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOSではミリ秒精度で測定
    timer=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s)
  else
    # Linuxではナノ秒対応
    timer=$(($(date +%s%N)/1000000))
  fi
}

precmd() {
  # キャッシュの更新処理
  if ! _prompt_cache_valid; then
    _prompt_cache_dir="$PWD"
    _prompt_cache_timestamp=$(date +%s)
  fi
  
  # 実行時間の表示処理
  if [[ -n $timer ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      now=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s)
      elapsed=$((now - timer))
    else
      now=$(($(date +%s%N)/1000000))
      elapsed=$((now - timer))
    fi
    
    # 5秒以上（5000ms）の場合のみ表示
    if [[ $elapsed -gt 5000 ]]; then
      # 色設定を確実に読み込み
      autoload -U colors && colors
      print -P "%F{yellow}⏱ ${elapsed}ms%f"
    fi
    
    unset timer
  fi
}

# シンプルなプロンプト設定
if [[ "$TERM" != "dumb" ]]; then
  # 色を確実に読み込み
  autoload -U colors && colors
  
  # プロンプト展開を有効化
  setopt PROMPT_SUBST
  
  # 2行プロンプト（すべての推奨項目表示）
  PROMPT='%F{cyan}$(smart_pwd)%f$(git_prompt_info)$(python_env_info)$(aws_env_info)$(terraform_env_info)
%F{yellow}❯%f%{$reset_color%} '
  
  # 右側プロンプト（時刻とコマンド実行時間）
  RPROMPT='%F{8}%T%f'
else
  # ダムターミナル用のシンプルプロンプト
  PROMPT='$ '
fi

