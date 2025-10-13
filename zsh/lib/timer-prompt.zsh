#!/usr/bin/env zsh
# ============================================================================
# timer-prompt.zsh - コマンド実行時間測定モジュール
# ============================================================================
# コマンドの実行時間を測定し、長時間実行された場合に表示

# タイマー設定
typeset -g _timer_threshold=5000  # 5秒（5000ms）以上で表示
typeset -g _timer_start=0

# 高精度時間取得関数（プラットフォーム対応）
_get_timestamp_ms() {
  local timestamp
  
  # Zsh 5.8.1以降のEPOCHREALTIMEを優先使用
  if (( ${+EPOCHREALTIME} )); then
    timestamp=${EPOCHREALTIME%.*}000  # ミリ秒変換
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS向けフォールバック
    timestamp=$(command python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null)
    # pythonが失敗した場合の最終フォールバック
    if [[ -z "$timestamp" ]]; then
      timestamp=$(($(date +%s) * 1000))
    fi
  else
    # Linux向けフォールバック
    timestamp=$(($(date +%s%N)/1000000))
  fi
  
  echo "$timestamp"
}

# コマンド実行開始時に呼ばれる関数
preexec() {
  _timer_start=$(_get_timestamp_ms)
}

# プロンプト表示前に呼ばれる関数
precmd() {
  # タイマーが設定されている場合のみ処理
  if [[ -n "$_timer_start" && "$_timer_start" -gt 0 ]]; then
    local now elapsed
    now=$(_get_timestamp_ms)
    elapsed=$((now - _timer_start))
    
    # しきい値以上の場合のみ表示
    if [[ $elapsed -ge $_timer_threshold ]]; then
      # 実行時間をフォーマットして表示
      if [[ $elapsed -ge 60000 ]]; then
        # 1分以上の場合は分:秒で表示
        local minutes seconds
        minutes=$((elapsed / 60000))
        seconds=$(((elapsed % 60000) / 1000))
        print -P "%F{yellow}⏱ ${minutes}m${seconds}s%f"
      else
        # 1分未満の場合はミリ秒で表示
        print -P "%F{yellow}⏱ ${elapsed}ms%f"
      fi
    fi
    
    # タイマーをリセット
    _timer_start=0
  fi
}

# タイマーしきい値を設定する関数
set_timer_threshold() {
  local threshold=$1
  
  if [[ -z "$threshold" ]]; then
    echo "現在のタイマーしきい値: ${_timer_threshold}ms"
    echo "使用法: set_timer_threshold <ミリ秒>"
    return 1
  fi
  
  if [[ "$threshold" =~ ^[0-9]+$ ]]; then
    _timer_threshold=$threshold
    echo "タイマーしきい値を ${threshold}ms に設定しました"
  else
    echo "エラー: 数値を指定してください" >&2
    return 1
  fi
}

# タイマーを手動でリセットする関数
reset_timer() {
  _timer_start=0
  echo "タイマーをリセットしました"
}