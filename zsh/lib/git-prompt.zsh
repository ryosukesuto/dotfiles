#!/usr/bin/env zsh
# ============================================================================
# git-prompt.zsh - Git情報表示とキャッシュ機能
# ============================================================================
# Git情報の取得とキャッシュを効率的に管理するモジュール

# Git関連キャッシュ変数の初期化
typeset -g _git_cache_dir=""
typeset -g _git_cache_branch=""
typeset -g _git_cache_status=""
typeset -g _git_cache_repo_name=""
typeset -g _git_cache_timestamp=0

# Git関連キャッシュの有効期限（秒）
# 環境変数 GIT_PROMPT_CACHE_TTL で変更可能（デフォルト: 30秒）
# 例: export GIT_PROMPT_CACHE_TTL=60  # 1分間キャッシュ
typeset -g _git_cache_ttl="${GIT_PROMPT_CACHE_TTL:-30}"

# Gitキャッシュが有効かチェックする関数
_git_cache_valid() {
  local current_time current_dir
  
  # Zsh組み込み変数を優先使用（パフォーマンス向上）
  if (( ${+EPOCHSECONDS} )); then
    current_time=$EPOCHSECONDS
  else
    current_time=$(date +%s)
  fi
  
  current_dir="$PWD"
  
  # ディレクトリが変わった場合やキャッシュが期限切れの場合は無効
  [[ "$current_dir" == "$_git_cache_dir" ]] && 
  [[ $((current_time - _git_cache_timestamp)) -le $_git_cache_ttl ]]
}

# Gitキャッシュをクリアする関数
_git_cache_clear() {
  _git_cache_dir=""
  _git_cache_branch=""
  _git_cache_status=""
  _git_cache_repo_name=""
  _git_cache_timestamp=0
}

# Git情報を一括取得して更新する関数
_git_cache_update() {
  # キャッシュが有効な場合は更新不要
  _git_cache_valid && return 0
  
  local git_info repo_root branch_line branch git_status
  
  # 現在のディレクトリとタイムスタンプを更新
  _git_cache_dir="$PWD"
  if (( ${+EPOCHSECONDS} )); then
    _git_cache_timestamp=$EPOCHSECONDS
  else
    _git_cache_timestamp=$(date +%s)
  fi
  
  # Gitリポジトリ内かチェック（1回のgitコマンドで判定）
  if git_info=$(git status --porcelain=v1 --branch 2>/dev/null); then
    # リポジトリ名の取得
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$repo_root" ]]; then
      _git_cache_repo_name=$(basename "$repo_root")
    else
      _git_cache_repo_name=""
    fi
    
    # ブランチ名の抽出（status --branchの最初の行から）
    branch_line=$(echo "$git_info" | head -1)
    if [[ "$branch_line" == "## "* ]]; then
      # "## " を削除し、空白や...以降を除去
      branch=${branch_line#"## "}
      branch=${branch%% *}
      branch=${branch%%...*}
      # HEAD (detached)の場合の処理
      if [[ "$branch" == "HEAD" ]]; then
        branch=$(git rev-parse --short HEAD 2>/dev/null || echo "detached")
      fi
    else
      branch="unknown"
    fi
    
    # 作業ディレクトリの状態をチェック（porcelainの2行目以降）
    if [[ $(echo "$git_info" | wc -l) -gt 1 ]]; then
      git_status=" %F{red}✗%f"
    else
      git_status=" %F{green}✓%f"
    fi
    
    _git_cache_branch=" %F{magenta}$branch%f$git_status"
  else
    # Gitリポジトリ外
    _git_cache_repo_name=""
    _git_cache_branch=""
  fi
}

# リポジトリ名を取得する関数
git_repo_name() {
  _git_cache_update
  echo "$_git_cache_repo_name"
}

# Git情報を表示する関数
git_prompt_info() {
  _git_cache_update
  echo "$_git_cache_branch"
}

# スマートなディレクトリ表示（リポジトリ内ではリポジトリ名のみ）
smart_pwd() {
  local repo_name_val
  repo_name_val=$(git_repo_name)
  
  if [[ -n "$repo_name_val" ]]; then
    # Gitリポジトリ内の場合はリポジトリ名のみ表示
    echo "$repo_name_val"
  else
    # Gitリポジトリ外では最後の2階層のみ表示
    local current_path="%~"
    local pwd_depth slash_count
    
    # パフォーマンス改善: pwdとホームディレクトリの比較
    if [[ "$PWD" != "$HOME"* ]] && [[ "$PWD" != "/" ]]; then
      # スラッシュの数を効率的にカウント
      slash_count=${#${PWD//[^\/]}}
      if [[ $slash_count -gt 2 ]]; then
        echo "$(basename $(dirname "$PWD"))/$(basename "$PWD")"
        return
      fi
    fi
    echo "$current_path"
  fi
}