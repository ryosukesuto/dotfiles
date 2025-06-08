# プロジェクト固有の環境変数
# 機密情報は ~/.env.local に記載してください

# デフォルト設定（必要に応じて ~/.env.local で上書き）
export DBT_AWS_ENV="${DBT_AWS_ENV:-staging}"

# 環境変数ファイルの読み込み（Gitで管理しない）
if [[ -f "$HOME/.env.local" ]]; then
  set -a  # 自動エクスポートを有効化
  source "$HOME/.env.local"
  set +a  # 自動エクスポートを無効化
fi

# プロジェクト固有のディレクトリでの環境変数読み込み
if [[ -f ".env.local" ]]; then
  set -a
  source ".env.local"
  set +a
fi