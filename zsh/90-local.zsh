#!/usr/bin/env zsh
# ============================================================================
# 90-local.zsh - ローカル環境設定
# ============================================================================
# このファイルはマシン固有の設定と機密情報を管理します。

# ============================================================================
# グローバル環境変数ファイルの読み込み
# ============================================================================
# ~/.env.localから環境変数を読み込む（Gitで管理しない）
if [[ -f "$HOME/.env.local" ]]; then
  set -a  # 自動エクスポートを有効化
  source "$HOME/.env.local"
  set +a  # 自動エクスポートを無効化
fi

# Supabase環境変数の読み込み（Gitで管理しない）
if [[ -f "$HOME/.supabase/.env.local" ]]; then
  set -a  # 自動エクスポートを有効化
  source "$HOME/.supabase/.env.local"
  set +a  # 自動エクスポートを無効化
fi

# ============================================================================
# プロジェクト固有の環境変数（セキュリティ強化版）
# ============================================================================
# 信頼できるディレクトリのホワイトリスト
typeset -g _DOTFILES_TRUSTED_DIRS=(
  "$HOME/src"
  "$HOME/work"
  "$HOME/projects"
  "$HOME/dev"
)

# 安全な.env.local読み込み関数
_dotfiles_load_project_env() {
  local env_file=".env.local"
  [[ ! -f "$env_file" ]] && return

  local current_dir="$(pwd)"

  # ホームディレクトリはグローバル環境変数として既に読み込み済み
  [[ "$current_dir" == "$HOME" ]] && return

  local is_trusted=false
  
  # ホワイトリストディレクトリ内かチェック
  for trusted_dir in "${_DOTFILES_TRUSTED_DIRS[@]}"; do
    if [[ "$current_dir" == "$trusted_dir"/* ]] || [[ "$current_dir" == "$trusted_dir" ]]; then
      is_trusted=true
      break
    fi
  done
  
  if [[ "$is_trusted" == "true" ]]; then
    # ファイル内容の基本検証（危険なパターンをチェック）
    if ! grep -qE '(curl|wget|rm\s+-rf|sudo|\$\(|\`|eval)' "$env_file" 2>/dev/null; then
      set -a
      source "$env_file"
      set +a
      # 成功時は静かに（DOTFILES_VERBOSE=1 で表示）
      [[ -n "$DOTFILES_VERBOSE" ]] && echo "✅ Loaded $env_file"
    else
      echo "⚠️ $env_file contains potentially dangerous commands - skipped"
    fi
  else
    echo "⚠️ $env_file found in untrusted directory: $current_dir"
    echo "   Add to trusted directories or move to: ${_DOTFILES_TRUSTED_DIRS[1]}"
  fi
}

# プロジェクト環境変数の読み込み実行
_dotfiles_load_project_env