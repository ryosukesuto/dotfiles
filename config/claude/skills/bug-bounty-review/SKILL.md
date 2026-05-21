---
name: bug-bounty-review
description: Bug Bountyレポートを評価し、Codexと協業して返信文を作成。「Bug Bountyレポートを評価して」「脆弱性レポートをレビューして」等で起動。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Bug Bounty Review

Bug Bountyレポートを評価し、Codexと協業して返信文を作成するスキル。

## ワークフロー

### 1. レポート分析

ユーザーから提供されたBug Bountyレポートを分析し、以下を評価する：

- 報告内容の技術的妥当性
- 脅威レベル（Critical / High / Medium / Low / Informational）
- 推奨対応（To Fix / Close Informative / Invalidate など）
- 対応理由（Not Applicable / Out of Scope / Not Reproducible / Duplicate）

### 2. 評価の観点

以下の観点で評価する：

#### クライアントサイドトークン/キーの公開
- Firebase API Key、Datadog Client Token（pub*）、Sentry DSNなどはフロントエンド公開が前提の設計
- これらの公開自体は脆弱性ではない
- 緩和策（ドメイン制限、レート制限等）の有無を確認

#### ユーザー列挙（User Enumeration）
- 多くのサービスで「登録済みかどうか」は標準的に返される
- 単独では低リスク、他の脆弱性との組み合わせで評価

#### 情報漏洩
- 公開情報 vs 機密情報の区別
- 実際の影響範囲

### 3. Codexによるセカンドオピニオン

このステップは原則必須。「CLI 環境だから」「環境がよく分からないから」で自主判断スキップしない。判定は実行環境への思い込みではなく `pane-manager.sh status` の出力で行う。

判定手順:

```bash
~/.claude/skills/codex-review/scripts/pane-manager.sh status
```

出力が `Backend: tmux` または `Backend: cmux` であれば実行する。`tmux/cmux 外` のエラーで返った場合のみスキップ可で、その旨を最終報告に明記する (「環境が cmux/tmux 外のため Codex セカンドオピニオン未実施」)。

実行例:

```bash
PANE_MGR=~/.claude/skills/codex-review/scripts/pane-manager.sh
$PANE_MGR ensure
$PANE_MGR send "【評価依頼内容】"
$PANE_MGR wait_response 300 && $PANE_MGR capture 400
```

Codex の指摘 (Severity / 切り分け / 表現等) は採用前に Claude Code 側で裏取りする (公式ドキュメント・コードベース確認)。技術的に妥当な指摘が出た場合は返信案に反映する。

### 4. 返信文作成

評価結果に基づいて英語の返信文を作成する。テンプレート：

#### 脆弱性ではない場合（Not Applicable）

```
Thank you for your report.

After reviewing your submission, we have determined that this does not constitute a security vulnerability.

[技術的な説明 - なぜ脆弱性ではないか]

While we appreciate your interest in our security, this report does not qualify for a bounty reward as it describes intended platform functionality rather than a vulnerability.

Best regards,
Security Team
```

#### 修正対応する場合（To Fix）

```
Thank you for your report.

We have reviewed your submission and confirmed the vulnerability. We are currently working on a fix.

[認識した問題の概要]

We will update you once the fix has been deployed.

Best regards,
Security Team
```

### 5. 返信文のCodexレビュー

作成した返信文をCodexにレビューしてもらう：
- 英語として自然か
- 内容に問題がないか
- トーンが適切か

### 6. 出力

最終的な返信文を `/tmp/bug-bounty-response-{識別子}.txt` に出力する。

`/tmp/` は投稿者ローカルファイルでセキュリティチームから参照不能。Bug Bounty Notify の Slack スレッドに結果を投稿する場合は、以下 2 点をスレッド上で完結させる:

1. トリアージサマリ (Severity / 対応 / 根拠 / 修正前の検証ポイント等を箇条書きで)
2. 英語返信ドラフト本文 (コードブロック ``` で囲んで貼り出す)

1 メッセージにまとめても 2 メッセージに分けても可。ローカルパス (`/tmp/...`) への参照だけで終わらせない。Slack はテーブル描画が弱いので、Markdown テーブルではなく箇条書き・絵文字で構造化する。

## よくあるパターンと対応

| 報告内容 | 脅威レベル | 対応 | 理由 |
|---------|-----------|------|------|
| Firebase API Key公開 | Informational | Close | Not Applicable |
| Datadog Client Token公開 | Informational | Close | Not Applicable |
| Sentry DSN公開 | Informational | Close | Not Applicable |
| ユーザー列挙（標準機能） | Low/Informational | Close | Not Applicable |
| 古いライブラリバージョン（悪用不可） | Informational | Close | Not Applicable |
| CORS設定ミス（実害あり） | Medium〜High | To Fix | - |
| 認証バイパス | High〜Critical | To Fix | - |

## 注意事項

- 最終判断は必ず人間が行う
- Codexの確認は「リスク棚卸完了」であり、出荷基準ではない
- 不明な場合はセキュリティチームに相談

## Gotchas

(運用しながら追記)
