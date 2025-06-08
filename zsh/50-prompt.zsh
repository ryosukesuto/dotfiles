# プロンプトのカスタマイズ

# 色の定義
autoload -U colors && colors

# Git情報を表示する関数
git_prompt_info() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
    local status=""
    
    # 作業ディレクトリの状態をチェック
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
      status="%{$fg[red]%}✗%{$reset_color%}"
    else
      status="%{$fg[green]%}✓%{$reset_color%}"
    fi
    
    echo " %{$fg[blue]%}($branch$status%{$fg[blue]%})%{$reset_color%}"
  fi
}

# Python仮想環境を表示する関数
python_env_info() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo " %{$fg[yellow]%}($(basename $VIRTUAL_ENV))%{$reset_color%}"
  elif command -v pyenv &> /dev/null && [[ "$(pyenv version-name)" != "system" ]]; then
    echo " %{$fg[yellow]%}(py:$(pyenv version-name))%{$reset_color%}"
  fi
}

# Node.js環境を表示する関数
node_env_info() {
  if [[ -f package.json ]] && command -v node &> /dev/null; then
    echo " %{$fg[green]%}(node:$(node --version | sed 's/v//'))%{$reset_color%}"
  fi
}

# 実行時間を測定する関数（Starship使用時は無効化）
if ! command -v starship &> /dev/null; then
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
fi

# シンプルなプロンプト設定
if [[ "$TERM" != "dumb" ]]; then
  # 2行プロンプト
  PROMPT='%{$fg[cyan]%}%n@%m%{$reset_color%} %{$fg[blue]%}%~%{$reset_color%}$(git_prompt_info)$(python_env_info)$(node_env_info)
%{$fg[magenta]%}❯%{$reset_color%} '
  
  # 右側プロンプト（時刻表示）
  RPROMPT='%{$fg[grey]%}%T%{$reset_color%}'
else
  # ダムターミナル用のシンプルプロンプト
  PROMPT='$ '
fi

# プロンプトテーマの切り替え関数
prompt_minimal() {
  PROMPT='%{$fg[blue]%}%~%{$reset_color%}$(git_prompt_info) %{$fg[magenta]%}❯%{$reset_color%} '
  RPROMPT=''
}

prompt_full() {
  PROMPT='%{$fg[cyan]%}%n@%m%{$reset_color%} %{$fg[blue]%}%~%{$reset_color%}$(git_prompt_info)$(python_env_info)$(node_env_info)
%{$fg[magenta]%}❯%{$reset_color%} '
  RPROMPT='%{$fg[grey]%}%T%{$reset_color%}'
}

# Starshipプロンプトがインストールされている場合は優先使用
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
  # Starship使用時はカスタムプロンプトを無効化
  unset PROMPT RPROMPT
fi