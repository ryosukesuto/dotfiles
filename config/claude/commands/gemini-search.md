---
description: Gemini APIを使用してWeb検索を実行
---

# Gemini Web検索

Google Gemini APIを使用してWeb検索を実行し、検索結果を要約して表示します。

## 前提条件

1. **Gemini CLIのインストール確認**
   ```bash
   command -v gemini || echo "Gemini CLIがインストールされていません"
   ```

2. **必要に応じてインストール**
   ```bash
   npm install -g @google/gemini-cli
   ```

3. **初回設定の確認**
   - `gemini` コマンドを実行してGoogleアカウントと連携済みか確認

## 検索機能

### 基本検索
ユーザーからの検索クエリに対して、Gemini APIのWeb検索機能を使用して検索を実行します。

```bash
# 使用可能な検索関数を確認
type gsearch || echo "gsearch関数が未定義"
type gtech || echo "gtech関数が未定義"
type gnews || echo "gnews関数が未定義"
```

### 検索の実行プロセス

1. **検索クエリの取得**
   - ユーザーから検索したい内容を取得

2. **検索タイプの判断**
   - 一般検索: `gsearch` または `gs`
   - 技術検索: `gtech` (StackOverflow、GitHub等の技術サイトに限定)
   - ニュース検索: `gnews` (最新ニュースを検索)

3. **検索実行**
   ```bash
   # 一般検索
   gsearch "検索クエリ"
   
   # 技術検索
   gtech "技術キーワード"
   
   # ニュース検索
   gnews "トピック"
   ```

4. **結果の表示**
   - Gemini APIが検索結果を要約して表示
   - 関連するWebページのリンクも含む

## 高度な使用方法

### 検索履歴の管理
```bash
# 履歴付き検索
gsearch-with-history "検索クエリ"

# 検索履歴の表示
gsearch-history
```

### 直接Gemini CLIを使用
より細かい制御が必要な場合：
```bash
gemini --prompt "WebSearch: <詳細な検索クエリ>"
```

## 使用例

1. **一般的な情報検索**
   ```bash
   gsearch "React 19 新機能"
   ```

2. **技術的な問題解決**
   ```bash
   gtech "Next.js 14 app router エラー解決"
   ```

3. **最新ニュース**
   ```bash
   gnews "AI 最新動向"
   ```

## トラブルシューティング

### Gemini CLIが見つからない場合
```bash
# グローバルインストール
npm install -g @google/gemini-cli

# 初期設定
gemini
```

### 関数が定義されていない場合
```bash
# 関数の読み込み
source ~/src/github.com/ryosukesuto/dotfiles/zsh/functions/gemini-search.zsh
```

## 注意事項
- Gemini APIの使用にはGoogleアカウントとの連携が必要
- APIの使用量に応じた料金が発生する可能性がある
- 検索結果はAIによる要約のため、必要に応じて元のWebページを確認すること