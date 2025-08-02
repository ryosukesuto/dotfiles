#!/usr/bin/env zsh
# ============================================================================
# env-prompt.zsh - 開発環境情報表示モジュール
# ============================================================================
# Python、AWS、Terraform等の環境情報をキャッシュ付きで表示

# 環境情報キャッシュ変数の初期化
typeset -g _env_cache_python=""
typeset -g _env_cache_aws=""
typeset -g _env_cache_terraform=""
typeset -g _env_cache_dir=""
typeset -g _env_cache_timestamp=0

# 環境情報キャッシュの有効期限（秒）
typeset -g _env_cache_ttl=30

# 環境キャッシュが有効かチェックする関数
_env_cache_valid() {
  local current_time current_dir
  
  # Zsh組み込み変数を優先使用
  if (( ${+EPOCHSECONDS} )); then
    current_time=$EPOCHSECONDS
  else
    current_time=$(date +%s)
  fi
  
  current_dir="$PWD"
  
  # ディレクトリが変わった場合やキャッシュが期限切れの場合は無効
  [[ "$current_dir" == "$_env_cache_dir" ]] && 
  [[ $((current_time - _env_cache_timestamp)) -le $_env_cache_ttl ]]
}

# 環境キャッシュをクリアする関数
_env_cache_clear() {
  _env_cache_python=""
  _env_cache_aws=""
  _env_cache_terraform=""
  _env_cache_dir=""
  _env_cache_timestamp=0
}

# Python環境情報を更新する関数
_update_python_cache() {
  local python_version
  
  if [[ -n "$VIRTUAL_ENV" ]]; then
    _env_cache_python=" %F{yellow}(🐍$(basename "$VIRTUAL_ENV"))%f"
  elif command -v mise &> /dev/null; then
    python_version=$(mise current python 2>/dev/null | cut -d' ' -f2)
    if [[ -n "$python_version" && "$python_version" != "system" ]]; then
      _env_cache_python=" %F{yellow}(🐍py:$python_version)%f"
    else
      _env_cache_python=""
    fi
  else
    _env_cache_python=""
  fi
}

# AWS環境情報を更新する関数
_update_aws_cache() {
  if [[ -n "$AWS_PROFILE" ]]; then
    _env_cache_aws=" %F{208}(☁️ aws:$AWS_PROFILE)%f"
  else
    _env_cache_aws=""
  fi
}

# Terraform環境情報を更新する関数
_update_terraform_cache() {
  local workspace
  
  # Terraformファイルが存在し、terraformコマンドが利用可能な場合のみ
  if [[ -f *.tf(#qN) ]] && command -v terraform &> /dev/null; then
    workspace=$(terraform workspace show 2>/dev/null)
    if [[ -n "$workspace" && "$workspace" != "default" ]]; then
      _env_cache_terraform=" %F{magenta}(💠tf:$workspace)%f"
    else
      _env_cache_terraform=""
    fi
  else
    _env_cache_terraform=""
  fi
}

# 環境キャッシュを更新する関数
_env_cache_update() {
  # キャッシュが有効な場合は更新不要
  _env_cache_valid && return 0
  
  # キャッシュ情報を更新
  _env_cache_dir="$PWD"
  if (( ${+EPOCHSECONDS} )); then
    _env_cache_timestamp=$EPOCHSECONDS
  else
    _env_cache_timestamp=$(date +%s)
  fi
  
  # 各環境情報を更新
  _update_python_cache
  _update_aws_cache
  _update_terraform_cache
}

# Python仮想環境を表示する関数
python_env_info() {
  # 最新の情報が必要な場合のみ更新
  if ! _env_cache_valid || [[ -z "$_env_cache_python" ]]; then
    _update_python_cache
  fi
  echo "$_env_cache_python"
}

# AWS環境を表示する関数
aws_env_info() {
  # 最新の情報が必要な場合のみ更新
  if ! _env_cache_valid || [[ -z "$_env_cache_aws" ]]; then
    _update_aws_cache
  fi
  echo "$_env_cache_aws"
}

# Terraform環境を表示する関数
terraform_env_info() {
  # 最新の情報が必要な場合のみ更新
  if ! _env_cache_valid || [[ -z "$_env_cache_terraform" ]]; then
    _update_terraform_cache
  fi
  echo "$_env_cache_terraform"
}

# 全環境情報を一括で取得する関数（パフォーマンス最適化用）
all_env_info() {
  _env_cache_update
  echo "$_env_cache_python$_env_cache_aws$_env_cache_terraform"
}