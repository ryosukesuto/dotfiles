# Git関連の便利関数

# Git add, commit, push を一度に実行
gacp() {
  if [[ -z "$1" ]]; then
    echo "エラー: コミットメッセージが必要です"
    echo "使用法: gacp \"コミットメッセージ\""
    return 1
  fi
  
  git add . && git commit -m "$1" && git push
}