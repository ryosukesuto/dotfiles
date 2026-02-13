# Bug Bounty Review

Bug Bountyレポートを評価し、Codexと協業して返信文を作成するスキル。

## トリガー

- `/bug-bounty-review` コマンド
- 「Bug Bountyレポートを評価して」「脆弱性レポートをレビューして」などの発言

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

tmux環境で実行している場合、tmux-codex-reviewを使ってCodexに確認を依頼する：

```bash
TMUX_MGR=~/.claude/skills/tmux-codex-review/scripts/tmux-manager.sh
$TMUX_MGR ensure
$TMUX_MGR send "【評価依頼内容】"
$TMUX_MGR wait_response 120 && $TMUX_MGR capture 300
```

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
