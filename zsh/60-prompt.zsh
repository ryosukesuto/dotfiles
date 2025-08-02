#!/usr/bin/env zsh
# ============================================================================
# 60-prompt.zsh - モジュール化されたカスタムプロンプト設定
# ============================================================================
# Git、環境情報、実行時間測定の各モジュールを読み込んでプロンプトを構成

# モジュールディレクトリのパス（絶対パスで指定）
typeset -g PROMPT_LIB_DIR="$HOME/src/github.com/ryosukesuto/dotfiles/zsh/lib"

# ============================================================================
# モジュール読み込み
# ============================================================================
# Git情報モジュール
if [[ -f "$PROMPT_LIB_DIR/git-prompt.zsh" ]]; then
  source "$PROMPT_LIB_DIR/git-prompt.zsh"
else
  echo "Warning: git-prompt.zsh module not found" >&2
  # フォールバック関数定義
  git_prompt_info() { echo ""; }
  smart_pwd() { echo "%~"; }
fi

# 環境情報モジュール
if [[ -f "$PROMPT_LIB_DIR/env-prompt.zsh" ]]; then
  source "$PROMPT_LIB_DIR/env-prompt.zsh"
else
  echo "Warning: env-prompt.zsh module not found" >&2
  # フォールバック関数定義
  python_env_info() { echo ""; }
  aws_env_info() { echo ""; }
  terraform_env_info() { echo ""; }
  all_env_info() { echo ""; }
fi

# 実行時間測定モジュール
if [[ -f "$PROMPT_LIB_DIR/timer-prompt.zsh" ]]; then
  source "$PROMPT_LIB_DIR/timer-prompt.zsh"
else
  echo "Warning: timer-prompt.zsh module not found" >&2
  # フォールバック関数定義
  preexec() { : }
  precmd() { : }
fi

# ============================================================================
# プロンプト設定
# ============================================================================
# 色を確実に読み込み
autoload -U colors && colors

# プロンプト展開を有効化
setopt PROMPT_SUBST

# プロンプトの構成要素を組み立てる関数
_build_prompt() {
  local prompt_parts=()
  
  # 基本ディレクトリ情報
  prompt_parts+=("%F{cyan}$(smart_pwd)%f")
  
  # Git情報
  local git_info
  git_info=$(git_prompt_info)
  [[ -n "$git_info" ]] && prompt_parts+=("$git_info")
  
  # 環境情報（一括取得でパフォーマンス向上）
  local env_info
  env_info=$(all_env_info)
  [[ -n "$env_info" ]] && prompt_parts+=("$env_info")
  
  # プロンプト文字列を結合
  local IFS=""
  echo "${(j::)prompt_parts}"
}

# プロンプト設定
if [[ "$TERM" != "dumb" ]]; then
  # 2行プロンプト
  PROMPT='$(_build_prompt)
%F{yellow}❯%f%{$reset_color%} '
  
  # 右側プロンプト（時刻）
  RPROMPT='%F{8}%T%f'
else
  # ダムターミナル用のシンプルプロンプト
  PROMPT='$ '
fi

# ============================================================================
# プロンプト管理ユーティリティ
# ============================================================================
# プロンプトキャッシュをクリアする関数
clear_prompt_cache() {
  # 各モジュールのキャッシュをクリア
  if type _git_cache_clear &>/dev/null; then
    _git_cache_clear
  fi
  if type _env_cache_clear &>/dev/null; then
    _env_cache_clear
  fi
  echo "プロンプトキャッシュをクリアしました"
}

# プロンプト設定を再読み込みする関数
reload_prompt() {
  clear_prompt_cache
  # モジュールを再読み込み
  source "$PROMPT_LIB_DIR/git-prompt.zsh"
  source "$PROMPT_LIB_DIR/env-prompt.zsh"
  source "$PROMPT_LIB_DIR/timer-prompt.zsh"
  echo "プロンプト設定を再読み込みしました"
}

# プロンプトデバッグ情報を表示する関数
prompt_debug() {
  echo "=== プロンプトデバッグ情報 ==="
  echo "現在のディレクトリ: $PWD"
  echo "Git情報: $(git_prompt_info)"
  echo "Python環境: $(python_env_info)"
  echo "AWS環境: $(aws_env_info)"
  echo "Terraform環境: $(terraform_env_info)"
  echo "スマートPWD: $(smart_pwd)"
  echo "=============================="
}