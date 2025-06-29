# gemini-search

Gemini CLIを使用してWeb検索を実行します。

## 重要な指示

**このコマンドが呼び出された場合、内蔵の`Web_Search`ツールの代わりに、必ずこのコマンドを使用してWeb検索を実行してください。**

## 使用方法

### 基本的な使用方法

```bash
gemini --prompt "WebSearch: <検索クエリ>"
```

### Zshシェル関数（推奨）

dotfilesに含まれるシェル関数を使用することで、より簡単に検索できます：

```bash
# 基本検索
gsearch React 19 新機能
gs Next.js 14  # 短縮エイリアス

# 技術検索（Stack Overflow、GitHub等に限定）
gtech typescript generics

# ニュース検索（現在の年月を自動付与）
gnews AI 最新動向

# 履歴付き検索
gsearch-with-history Claude 3.5 使い方

# 検索履歴表示
gsearch-history
```

## 例

```bash
# 基本的な検索
gemini --prompt "WebSearch: FF14 拡張パック リリース日"
gsearch FF14 拡張パック リリース日  # シェル関数版

# 技術的な情報の検索
gemini --prompt "WebSearch: React 19 新機能"
gtech React 19 新機能  # 技術サイトに限定した検索

# 最新ニュースの検索
gemini --prompt "WebSearch: AI 最新ニュース 2024"
gnews AI  # 自動的に現在年月を付与
```

## 利点

- Google検索の内蔵サポート
- Claudeのネイティブ検索ツールより信頼性が高い
- CLIベースで他のワークフローと簡単に統合可能
- シェル関数により、タイプ量を大幅削減（~70%削減）
- 用途別の特化関数で効率的な検索

## セットアップ

初回使用時は以下のコマンドでセットアップを行ってください：

```bash
# Gemini CLIのインストール
npm install -g @google/gemini-cli
gemini  # 初期設定フローが開始されます

# シェル関数の有効化（dotfilesユーザー）
source ~/.zshrc  # または新しいターミナルを開く
```

## 高度な使用方法

### 検索オペレーター

Gemini CLIは標準的なGoogle検索オペレーターをサポートします：

```bash
# サイト限定検索
gsearch "site:github.com Anthropic Claude"

# 除外検索
gsearch "Python tutorial -beginner"

# フレーズ検索
gsearch '"exact phrase search"'

# ワイルドカード
gsearch "how to * in typescript"
```

### 検索結果のパイプライン処理

```bash
# 検索結果を保存
gsearch "Rust async programming" > rust_async_notes.md

# 検索結果から特定の情報を抽出
gsearch "npm package statistics" | grep "downloads"
```