# Supabase Configuration

このディレクトリには、Supabase CLIと開発環境のための設定ファイルが含まれています。

## セットアップ

### 1. Supabase CLIのインストール

```bash
brew install supabase/tap/supabase
```

### 2. 認証

```bash
supabase login
```

トークンはmacOSのキーチェーンに安全に保存されます。

### 3. 設定ファイルの作成

```bash
# グローバル設定
cp config/supabase/config.toml.template ~/.supabase/config.toml

# プロジェクト設定
cp config/supabase/projects.toml.template ~/.supabase/projects.toml

# 環境変数（機密情報）
cp config/supabase/.env.local.template ~/.supabase/.env.local
```

### 4. プロジェクトへのリンク

```bash
# プロジェクトディレクトリで実行
supabase link --project-ref your-project-ref
```

## エイリアスと関数

### エイリアス

- `sb` - supabase
- `sbl` - supabase login
- `sbo` - supabase logout
- `sbp` - supabase projects list
- `sblink` - supabase link
- `sbdb` - supabase db
- `sbf` - supabase functions
- `sbm` - supabase migration
- `sbs` - supabase start
- `sbstop` - supabase stop

### ユーティリティ関数

- `sb-switch <project-ref>` - プロジェクトを切り替え
- `sb-info` - 現在のプロジェクト情報を表示
- `sb-list` - すべてのプロジェクトを表示
- `sb-status` - Supabase CLIのステータスチェック
- `sb-clean` - 一時ファイルをクリーンアップ
- `sb-env [file]` - 環境変数を読み込み
- `sb-db-url <password>` - データベース接続URLを生成
- `sb-migration-status` - マイグレーションステータスを表示
- `sb-migration-new <name>` - 新しいマイグレーションを作成

## セキュリティ

### 認証情報の管理

- **トークン**: OSのキーチェーンに保存（`supabase login`で自動管理）
- **APIキー**: `~/.supabase/.env.local`に保存（Gitで管理しない）
- **データベースパスワード**: 環境変数として管理

### ベストプラクティス

1. **機密情報をコミットしない**
   - `.env.local`ファイルは`.gitignore`に含まれています
   - テンプレートファイルのみをコミット

2. **環境変数の優先順位**
   ```
   環境変数 > ~/.supabase/.env.local > プロジェクト内.env.local
   ```

3. **共有端末での作業**
   ```bash
   # 作業終了時は必ずログアウト
   supabase logout
   ```

## トラブルシューティング

### プロジェクトリンクの確認

```bash
cat supabase/.temp/project-ref
```

### キャッシュのクリア

```bash
sb-clean
```

### 環境変数の確認

```bash
sb-env
echo $SUPABASE_URL
```

## 参考リンク

- [Supabase CLI Documentation](https://supabase.com/docs/guides/cli)
- [Supabase Dashboard](https://supabase.com/dashboard)