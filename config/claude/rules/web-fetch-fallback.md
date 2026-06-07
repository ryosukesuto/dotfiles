# Web取得のフォールバック: Jinaを使う

## ルール

WebFetch・X（Twitter）・その他のサイトから本文が取得できないときは、Jina Reader (`https://r.jina.ai/<url>`) にフォールバックする。

## 判定基準

以下のシグナルが出たらJinaに切り替える:

- WebFetch が SPA でレンダリングされたコンテンツを返さず、骨組みHTMLや「JavaScriptを有効にしてください」を返す
- WebFetch が 403 / 401 / 429 / robots.txt ブロックで失敗する
- X / Twitter の URL を読むよう指示されたが、WebFetchではログインページにリダイレクトされる
- ニュースサイト・ブログでpaywall手前のスニペットしか取れない
- ユーザーが明示的に「Jinaで読んで」と指示した

## 使い方

```bash
curl -s "https://r.jina.ai/<元のURL>"
```

例:

```bash
curl -s "https://r.jina.ai/https://x.com/user/status/1234567890"
curl -s "https://r.jina.ai/https://example.com/article"
```

Markdown形式で本文が返ってくる。`Title:` / `URL Source:` / `Published Time:` のヘッダ付き。

## 制約

- 画像の中身は抽出されない。X投稿に添付された画像のテキスト・スクリーンショットは読めない（画像URLは取れるが中身は別途解析が必要）
- 認証が必要なページ（プライベートGist、限定公開ツイート等）は取得できない
- 巨大なページはトークンを大量消費するので、必要部分だけ抽出する意識を持つ
- Jinaの無料tierにはrate limitがある。連続して大量に叩かない

## 関連

- 社内ナレッジは `mcp__ragent__hybrid_search` を使う（`knowledge-search.md`）
- Jinaは公開Webの取得限定。社内Wikiやnotionには使わない
