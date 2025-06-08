# プロンプトのカスタマイズ

# 色の定義
autoload -U colors && colors

# リポジトリ名を表示する関数
repo_name() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n $repo_root ]]; then
      echo $(basename "$repo_root")
    fi
  fi
}

# Git情報を表示する関数
git_prompt_info() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
    local git_status=""
    
    # 作業ディレクトリの状態をチェック
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
      git_status=" %F{red}✗%f"
    else
      git_status=" %F{green}✓%f"
    fi
    
    echo " %F{magenta}$branch%f$git_status"
  fi
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

# Python仮想環境を表示する関数
python_env_info() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo " %F{yellow}(🐍$(basename $VIRTUAL_ENV))%f"
  elif command -v pyenv &> /dev/null; then
    local pyenv_version=$(pyenv version-name 2>/dev/null)
    if [[ -n "$pyenv_version" && "$pyenv_version" != "system" ]]; then
      echo " %F{yellow}(🐍py:$pyenv_version)%f"
    fi
  fi
}

# Node.js環境を表示する関数
node_env_info() {
  if [[ -f package.json ]] && command -v node &> /dev/null; then
    echo " %F{green}(⬢ node:$(node --version | sed 's/v//'))%f"
  fi
}

# Go環境を表示する関数
go_env_info() {
  if [[ -f go.mod ]] && command -v go &> /dev/null; then
    echo " %F{cyan}(🐹go:$(go version | awk '{print $3}' | sed 's/go//'))%f"
  fi
}

# AWS環境を表示する関数
aws_env_info() {
  if [[ -n "$AWS_PROFILE" ]]; then
    echo " %F{208}(☁️ aws:$AWS_PROFILE)%f"
  fi
}

# Terraform環境を表示する関数
terraform_env_info() {
  if [[ -f *.tf ]] && command -v terraform &> /dev/null; then
    local workspace=$(terraform workspace show 2>/dev/null)
    if [[ -n "$workspace" && "$workspace" != "default" ]]; then
      echo " %F{magenta}(💠tf:$workspace)%f"
    fi
  fi
}

# Kubernetes環境を表示する関数
k8s_env_info() {
  if command -v kubectl &> /dev/null; then
    local context=$(kubectl config current-context 2>/dev/null)
    if [[ -n "$context" ]]; then
      echo " %F{cyan}(⎈ k8s:$(echo $context | cut -d'/' -f1))%f"
    fi
  fi
}

# Docker環境を表示する関数
docker_env_info() {
  if [[ -n "$DOCKER_CONTEXT" && "$DOCKER_CONTEXT" != "default" ]]; then
    echo " %F{blue}(🐳docker:$DOCKER_CONTEXT)%f"
  fi
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
  PROMPT='%F{cyan}$(smart_pwd)%f$(git_prompt_info)$(python_env_info)$(node_env_info)$(go_env_info)$(aws_env_info)$(terraform_env_info)$(k8s_env_info)$(docker_env_info)
%F{yellow}❯%f%{$reset_color%} '
  
  # 右側プロンプト（時刻とコマンド実行時間）
  RPROMPT='%F{8}%T%f'
else
  # ダムターミナル用のシンプルプロンプト
  PROMPT='$ '
fi

