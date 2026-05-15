---
name: wiz-triage
description: Wizアラートのトリアージと調査を支援。「Wizアラート」「Wiz対応」「セキュリティアラート」等で起動。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - mcp__linear-server__save_issue
  - mcp__linear-server__get_issue
  - mcp__datadog-mcp__search_datadog_logs
  - mcp__datadog-mcp__search_datadog_events
  - mcp__ragent__hybrid_search
---

# Wiz Triage

Wizアラートのトリアージと調査を支援するskill。

## ワークフロー

### Phase 0: 自己発火パターンの確認（先にやる）

アラートの actor / IP / 時刻が自分たちのチームの作業に紐づく可能性を最初に潰す。これを怠ると外部攻撃者として誤って深掘りしてしまう。

1. **actor IP の whois**: `whois <ip>` で所有組織を確認。`IIJ-CA / CyberAgent, Inc.` 等の社内 NAT なら社員行動である強い証拠
2. **User-Agent の解読**: `gcloud/* command/gcloud.xxx` のように対話型 SDK のコマンド名が出ていたら社員端末発信。`google-api-go-client/...Kubernetes/...` のような SDK 由来なら正規 service 経由
3. **時刻照合**: 検出時刻と自分の作業セッション（git log / Slack 発言 / シェル履歴）が一致しないか確認。ユーザー本人に「この時刻に何をしていたか」を尋ねるのも有効
4. **Wiz の actor=`allUsers` は要注意**: impersonation や認証失敗で principal が未解決の場合、Wiz は actor を `allUsers` の placeholder で表示する。User-Agent と IP の方が信頼できる
5. **関連 memory を参照**: 既知の自己発火パターン（[[wiz-self-triggered-token-failure]] 等）に該当しないか確認

該当した場合は Phase 1 を skip して Phase 3 (Wiz 解決のみ) に飛ぶ。Linear 起票は不要。

### Phase 1: Linear Issue 作成（必要な場合のみ）

Phase 0 で自己発火と判定できなかった、または継続的な調査が必要な場合のみ起票する。即時解決可能なノイズに毎回 issue を切ると Cycle が膨れる。

アラート内容から以下を抽出してLinear issueを作成:

| 項目 | 設定値 |
|------|--------|
| Team | (organization 固有。`${CLAUDE_SKILL_DIR}/SKILL.local.md` 参照) |
| Title | `[Wiz {Severity}] {リソース名}: {検出内容の要約}` |
| Assignee | `me` |
| Estimate | `2` (調査込みの通常作業) |
| Cycle | `current` |
| State | `Todo` |
| Project | (organization 固有。`${CLAUDE_SKILL_DIR}/SKILL.local.md` 参照) |

Description テンプレート:
```markdown
## アラート概要

{アラートの説明}

| 項目 | 内容 |
|------|------|
| Severity | {High/Critical} |
| 検出日時 | {日時} |
| リソース | {リソース名} |
| MITRE ATT&CK | {該当する場合} |

### 検出内容

{詳細}

---

## 調査結果

(調査後に記入)

---

## 結論

| 項目 | 結果 |
|------|------|
| 脆弱性有無 | |
| 被害有無 | |
| 対応 | |
```

### Phase 2: 調査ガイド

アラートタイプに応じた調査観点を提示:

#### Threats（脅威）の場合
1. **ログ調査**
   - Datadogでサービスログを確認
   - GCP Cloud Loggingで詳細確認
   - 検出時刻前後のリクエストパターン分析

2. **コード調査**（必要に応じて）
   - 該当機能のコードを確認
   - 脆弱性の有無を判断

3. **関連情報確認**
   - Bug Bounty報告の有無
   - 同様のアラートの過去事例

#### Risk Issue（リスク課題）の場合
1. **設定確認**
   - 該当リソースの設定を確認
   - 意図した設定かどうか判断

2. **影響範囲確認**
   - 他に同様の設定がないか確認

#### 因果関係の検証（全タイプ共通）
原因候補を特定したら、Linear issueの調査結果に記入する前に:
1. 「この原因候補が無関係だとしたら、他に何が考えられるか」を1つ以上挙げる
2. 検出時刻前後で無関係なイベントが同時発生していないか確認する
3. 調査結果には断定表現を避け、根拠とともに記載する

### Phase 3: 結果出力

調査完了後、以下を出力:

1. **Linear issueの更新**
   - 調査結果セクションを記入
   - 結論を記入

2. **Wiz用コメント**
   - `/tmp/wiz-comment-{issue番号}.txt` に出力
   - Wiz の「理由」フィールドはプレーンテキスト。バッククォート / 太字 / markdown 見出しは使わない
   - **デフォルトは 1-2 文の短い説明**。placeholder 「この脅威は解決された。なぜなら...」に自然に続く文体で書く
   - 必要な場合のみ判断根拠を箇条書きで足す。先に短い版を提示してユーザー判断を仰ぐ
   - 【原因】【判断理由】のような囲い見出しは付けず、本文で完結させる

短いテンプレート（デフォルト）:
```
{何が・なぜ起きたか・なぜ問題ないか を 1-2 文で}。{実害の有無}。
```

詳細テンプレート（短い版で説明不足な場合のみ使う）:
```
{要約: 何が起きて、なぜ問題ないと判断したか。1〜2文}

判断根拠:
- {根拠1}
- {根拠2}
- {根拠3}
```

Linear issue を切らなかった場合は Linear URL 行は不要。

実例 (organization 固有のリソース名・PR 番号・Linear URL を含む) は `${CLAUDE_SKILL_DIR}/SKILL.local.md` を参照する。

3. **対応方針の提示**
   - 脆弱性なし → Wizで「無視」または「解決」、issueをDone
   - 脆弱性あり → 対応計画を立案、issueは継続

### Wiz の「結論」ラベルの選び方

「リゾルブ・スレット」ダイアログの結論ラベルは以下で選ぶ。

| 結論 | 使う場面 |
|------|---------|
| 悪意のある | 攻撃確定。実害あり、または攻撃の試行が明確 |
| セキュリティテスト | ペネトレ・脆弱性診断・Bug Bounty など、認可された検査起因 |
| 計画された行動 | 正規の運用・正規 App・意図された機能による検出。Claude Code Action 初回 push などはここ |
| 悪意はありません | 偶発的なノイズ・誤操作。意図された運用とは言い切れないが攻撃ではないもの |
| 結論は出ていません | 調査未完。あとで再評価する |

迷ったら「自分たちが意図して入れた仕組みの動作か?」で分岐する。Yes なら `計画された行動`、No だが攻撃でもないなら `悪意はありません`。

## 参考情報

### Wizステータスの選択

| 状況 | Wizステータス | Linear |
|------|--------------|--------|
| 脆弱性なし | 無視（理由記載必須） | Done |
| 対応完了 | 対応済み | Done |
| 対応中 | Open | In Progress |

### よくあるアラートタイプと対応

| アラート | よくある原因 | 対応 |
|----------|-------------|------|
| DNS query for Burp Suite domains | MXレコード検証、メール送信機能 | 機能の正常動作なら無視 |
| IMDS access | GCP認証トークン取得 | 正常動作なら無視 |
| Suspicious outbound connection | 外部API呼び出し | 意図した通信か確認 |
| Git Push Or Merge Pull Requests By Unusual Bot User (`cer-github-identity-pushOrMergeByUnusualBotUser`) | Claude Code GitHub App (`claude[bot]`) の初回 PR 自動レビュー、または Dependabot / Renovate の初回 push | リポの `.github/workflows/claude*.yml` 等を確認し、workflow が `contents: read` のみで実コード変更権限がないことを確認したら `計画された行動` で解決 |
| Unusual Failed Attempts To Create Access Token For Admin Service Account (`cer-gcp-identity-unsualFailedCreationOfAdminServiceAccountAccessToken`) | Platform エンジニアによる CVE 影響調査等で `gcloud secrets versions access` + `--impersonate-service-account` を試行、`serviceAccountTokenCreator` 未付与で拒否 | 発信元 IP の whois が `IIJ-CA / CyberAgent, Inc.` で User-Agent が `gcloud` なら自己発火。詳細は [[wiz-self-triggered-token-failure]]、対応は `計画された行動` |

## Gotchas

- Wiz が `actor=allUsers` で表示するのは「未認証アクセス」ではなく「principal を解決できない失敗イベント」のケースが多い。impersonation 失敗・認証失敗・IAM 拒否のいずれかで principal 名が log に乗らなかった時に Wiz が placeholder として `allUsers` を入れている可能性が高い。User-Agent と actor IP の whois で実体を確認する
- `iamcredentials.googleapis.com.GenerateAccessToken` は組織レベルの IAM Credentials API。プロジェクト直下の audit log には残らないことが多く、Data Access logs を有効化していない限り Cloud Logging で再現確認はできない。Wiz の cloudEvents セクションが一次情報になる
- Wiz MCP は read-only。`get_*` / `list_*` のみで resolve / ignore / update_status の mutation tool は提供されていない。解決操作は Wiz portal UI で手動実施する
- `whois <ip>` の所有組織が `IIJ-CA / CyberAgent, Inc.` なら社内 NAT (CyberAgent オフィス出口)。社員作業の強い証拠
