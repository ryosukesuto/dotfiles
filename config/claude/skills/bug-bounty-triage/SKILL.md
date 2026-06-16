---
name: bug-bounty-triage
description: Bug Bountyレポートをトリアージし、重複チェック・分析・アクション決定・内部メモ・返信案・報奨金算定までを一貫して提案する。「Bug Bountyトリアージ」「脆弱性レポートをトリアージして」「Bug Bountyレポートを評価して」等で起動。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Bug Bounty Triage

IssueHunt 上の Bug Bounty レポートをトリアージし、重複チェック → 分析 → Codex セカンドオピニオン → アクション決定 → 内部メモ → 返信案 → 報奨金算定 → Slack 投下までを一貫してドラフト提案する skill。手動運用フローを 8 ステップで写像する。最終判断・送信・state 更新・報奨金支払いは PF チームが実施する (skill 側は提案ドラフトまで)。

組織固有の値 (CVSS×脆弱性種類の基本支払額表 / 影響度別上限額) は `${CLAUDE_SKILL_DIR}/SKILL.local.md` を参照する。dotfiles-public には書かない。

## ワークフロー

### 1. 重複チェック

新規レポートを受け取ったら、まず過去報告との重複を機械的に確認する。reporter の自己申告 ("関連: #115/#116" 等) だけに頼らない。

手順:

```
mcp__issuehunt__list_reports(orgId=<WINTICKET org>, perPage=50, page=1..N)
```

`search` パラメータは厳密一致寄りで title 部分一致でも 0 件が返る既知挙動 ([[issuehunt-search-quirks]])。最初から全件取得する。IssueHunt の state は 9 種類 (`new` / `triaged` / `resolved` / `not_applicable` / `duplicate` / `out_of_scope` / `informational` / `not_reproducible` / `unresolved`) あり、`list_reports` を state 無指定で叩いて取得しきれない場合は state ごとに 1 回ずつ叩いて網羅する。**`unresolved` を必ず含める** — canonical な既知 issue が triage 漏れで `unresolved` のまま放置されているケースがあり、ここを漏らすと duplicate target を見落とす。

取得後は以下 3 観点で grep する:

- 同 reporter の過去報告 (`Submitted By` 一致)
- 同 VRT (`server_security_misconfiguration|*|*` などの category 一致)
- 類似 title (主要キーワード 2-3 個の AND)

加えて `state=duplicate` の報告は **必ず `mcp__issuehunt__get_report_messages(reportId)` で reply を fetch する**。reply 本文に "duplicate of #N" や "similar to #N" の形で canonical target が書かれている (org 側 reply で internal note 代わりに使われる慣行)。これが内部 ticket scope を判定する一次情報になる。

重複候補が見つかった場合の処理:

| 状況 | 推奨 action |
|------|------------|
| 同内容が `triaged` で進行中 | `Invalidate` + state `duplicate` + 過去報告へのリンクを内部メモに記入 |
| 同内容が `resolved` で fix 済み | `Invalidate` + state `duplicate` + 内部メモに「#N で fix 済み (commit/PR を引用)」 |
| 同内容が `unresolved` で放置されている (canonical な既知 issue 候補) | ステップ 2 のコードレベル検証で fix 済みか確認 → fix 済みなら `Invalidate` + state `duplicate` + 内部メモに「#N の state を `resolved` に更新する cleanup 依頼を PF チームに」を付記。未着手なら `Invalidate` + state `duplicate` + 「#N 自体の priority 見直しを促す」を付記 |
| 同内容が過去に `not_applicable` / `informational` で閉じている | `Close (Informative)` + 過去報告へのリンクを内部メモに記入 |
| 同内容が過去に `resolved` だが今回再現可能 (regression 疑い) | `To Fix` + 内部メモに「#N の regression 疑い、engineering 検証要求」を記載。検証結果次第で bounty 確定または `Invalidate` (duplicate) に分岐 |
| 部分重複 (root cause が同じだが exploit 経路が違う) | 単独で進める。ただし内部メモに related report を列挙 |

### 2. レポート分析

`mcp__issuehunt__get_report(reportId)` でフルコンテンツ取得。以下を評価する:

- 報告内容の技術的妥当性
- 脅威レベル (Critical / High / Medium / Low / Informational)
- 対応理由 (Not Applicable / Out of Scope / Not Reproducible / Duplicate)

#### 評価の観点

クライアントサイドトークン/キーの公開
- Firebase API Key、Datadog Client Token (pub*)、Sentry DSN などはフロントエンド公開が前提の設計
- これらの公開自体は脆弱性ではない
- 緩和策 (ドメイン制限、レート制限等) の有無を確認

ユーザー列挙 (User Enumeration)
- 多くのサービスで「登録済みかどうか」は標準的に返される
- 単独では低リスク、他の脆弱性との組み合わせで評価

情報漏洩
- 公開情報 vs 機密情報の区別
- 実際の影響範囲

設定 dump 系 (configuration disclosure)
- Firebase の `getRecaptchaConfig` のように SDK が叩く client-facing endpoint からの設定取得は exploit ではない
- 「設定が UNSPECIFIED」「protection が disabled」の主張は hardening recommendation であって vulnerability ではない

#### Priority (P1-P5) 判定

Bugcrowd VRT 1.18 (<https://bugcrowd.com/vulnerability-rating-taxonomy>) の priority 体系で finding ごとに P1-P5 を決める。Severity (Informational/Low/Medium/High/Critical) と並列に VRT 公式の baseline priority を明示することで、program 側の reward range マッピングと突き合わせやすくなる。

判定基準 (典型例):

- **P1 (Critical)**: 認証バイパスでの管理者権限奪取、リモートコード実行 (Server-Side / Client-Side RCE)、SQL Injection でデータベース全取得、本番 secret の直接露出 (API gateway master key / DB credential 等で実害導通)、決済・残高操作系
- **P2 (High)**: 認証された他ユーザーのアカウント乗っ取り (cross-account IDOR / 認可バイパス)、Stored XSS で全ユーザー影響、SSRF で内部 metadata service 到達、機微 PII の大量漏洩
- **P3 (Medium)**: Reflected XSS (cross-site で他人に投げ込める前提)、CSRF で状態変更、限定的 IDOR、Open Redirect で phishing 経路成立、サブドメインテイクオーバー、PR preview 用 secret の production への configuration drift
- **P4 (Low)**: 認証フローの軽微な弱点 (rate limit 不備、メール送信フラッディング)、HTML Injection、内部ホスト名露出、CSP / セキュリティヘッダ不足、外部から悪用しにくい情報漏洩
- **P5 (Informational)**: Self-XSS、Disclosure of Known Public Information、hardening 推奨、設定オフ系の指摘で実害シナリオなし、Intentionally Public / Sample / Invalid な key 露出

判定フロー:

1. reporter 自申告の VRT カテゴリ (`<category>|<subcategory>|<variant>` 形式) と CVSS スコアを確認 (信用せずあくまで初期値として扱う)
2. ステップ 2 のコードレベル検証結果と組み合わせて actual な exploit 可能性を判定
3. VRT 1.18 公式 JSON で該当カテゴリの `priority` フィールドを確認

   ```bash
   curl -fsSL https://bugcrowd.com/vulnerability-rating-taxonomy/1.18.json \
     | jq '.content[] | recurse(.children[]?) | select(.id == "<category_id>")'
   ```

4. program 側で variant rule (例: Self-XSS の P5 固定、認証不要 RCE の P1 固定) を当てはめる
5. Severity と Priority が乖離する場合は内部メモに理由を明記する (例: VRT 上は P3 だが影響範囲が極小なので reward は影響度「中」枠で算定)

VRT mapping の書式 (内部メモ・Slack 投下に共通):

```
- Finding N: <VRT category path> (P<priority>)
- 代替マッピング (該当する場合): <alt category path> (P<priority>)
```

VRT カテゴリ ID が複数該当しうる場合 (例: Reflected XSS + Disclosure of Known Public Information) は両方を列挙し、最も重い方を採用する。

1 レポート N findings の場合は finding ごとに独立して Priority を判定する (Severity と同様)。最終的な IssueHunt state は最も重い Priority に対応する action にマッピングする (P1-P2 → `To Fix`、P3 → 影響度と修正必要性次第、P4-P5 → `Close (Informative)` または hardening の `To Fix`)。

#### 実装側コードレベル検証 (production 影響を避ける優先経路)

reporter の主張 (特に「rate-limit がない」「特定 endpoint で auth が通る」「fix されていない」等) を裏取りする際は、ライブ PoC 再現を即実行する前に実装側コードを読んで結論を出す経路を**優先する**。

判定順:

1. **コードレベル検証** (第一推奨): 該当 endpoint / handler の実装をリポジトリで grep → 該当処理を Read → fix 該当 commit を `git log -S` で特定
   - 利点: production 無害、ログ・メトリクス・anomaly detection に影響しない、一次情報なので信頼度が高い、30 分以内で結論を出せることが多い
   - 適用条件: 該当リポジトリがローカルに clone 済み、reporter が叩いた endpoint の handler を特定できる
2. **ステージング再現** (第二推奨): production と同実装の staging endpoint があり credential が手元にあるなら staging で PoC を叩く
   - 適用条件: staging が同等実装、credential 取得可能、staging への影響が許容範囲
3. **ライブ PoC 再現** (最終手段): コードレベル検証で結論が出せない場合、または黒箱挙動の確認が必須の場合のみ。**PF チーム承認 + clean up 計画**を事前に揃える
   - リスク: production DB / Firebase Auth project にデータ追加、Wiz / Datadog の anomaly detection 発火、clean up に運用権限が必要、reporter PoC アカウントと自分のテストアカウントが混在する
   - 必要な事前合意: 試験用 email (`<self>+poc-*` エイリアス推奨)、clean up 担当、production 直叩きの authorized testing 文書の確認

コードレベル検証で fix commit を特定できた場合は、内部メモの `【根拠】` に commit hash / PR 番号 / merge 日付を引用する。これが PF チームの canonical target state 更新 (`unresolved` → `resolved`) の根拠になる。

#### 1 レポート N findings の取扱い

適用対象: 1 report 内に **2 つ以上の独立した finding** (root cause が異なる懸念) が含まれる場合のみ。1 finding のみのレポートには本節を適用せず、通常のテンプレート (内部メモ・英語返信のシングル構造) を使う。

1 レポートに複数の独立した finding (root cause が異なる懸念) が詰め込まれている場合の運用ルール:

- finding 単位で独立した triage 判断を行う (重複チェック・Severity 判定・アクション決定をそれぞれ独立に実施)
- 内部メモは finding 別ブロックで記述する (`### Finding 1: ...` のように見出しを切り、各 finding に判定セクションを置く)
- 英語返信は finding 単位の見出しで構成し、1 メッセージで全件カバーする
- 報奨金算定も finding 単位で行う (重複や hardening の finding には支払いなし、新規実害には個別算定)。Slack 投下ステップの「報奨金提案額 + 根拠」も finding 単位で列挙する
- IssueHunt の state は 1 report につき 1 つしか付けられないため、**最も重い finding** (To Fix > Informative > Duplicate の優先順) に合わせる
- 「複数 finding を 1 レポートに詰めるのは triage コストが高い」旨は英語返信で婉曲に伝え、次回以降 finding 別に分けて報告するよう促す (ただし強制ではない、program policy に沿う表現で)

### 3. Codexによるセカンドオピニオン

このステップは原則必須。「CLI 環境だから」「環境がよく分からないから」で自主判断スキップしない。判定は実行環境への思い込みではなく `pane-manager.sh status` の出力で行う。

判定手順:

```bash
~/.claude/skills/codex-review/scripts/pane-manager.sh status
```

出力が `Backend: tmux` または `Backend: cmux` であれば実行する。`tmux/cmux 外` のエラーで返った場合のみスキップ可で、その旨を最終報告に明記する (「環境が cmux/tmux 外のため Codex セカンドオピニオン未実施」)。

`Could not acquire lock after 10 attempts` や `ロックを取得できず、既存surfaceも見つからない` のエラーが出た場合は sandbox の `/tmp` 書き込み拒否が原因。スキップせず、`Bash` ツール呼び出しに `dangerouslyDisableSandbox: true` を付けて `status` から再実行する。これは `codex-review` skill の「## 前提条件 - Sandbox 環境での実行」セクションに明記されている既存の脱出手順。

実行例 (sandbox 制限環境):

```
Bash({
  command: "~/.claude/skills/codex-review/scripts/pane-manager.sh status",
  dangerouslyDisableSandbox: true
})
```

実行例 (通常):

```bash
PANE_MGR=~/.claude/skills/codex-review/scripts/pane-manager.sh
$PANE_MGR ensure
$PANE_MGR send "【評価依頼内容】"
$PANE_MGR wait_response 300 && $PANE_MGR capture 400
```

Codex の指摘 (Severity / 切り分け / 表現等) は採用前に Claude Code 側で裏取りする (公式ドキュメント・コードベース確認)。技術的に妥当な指摘が出た場合は返信案に反映する。

##### Codex が追加調査を要求した場合の対応

Codex は「内部 ticket scope を確認する必要がある」「該当実装の現状を確認する必要がある」のように、判定の前提となる追加調査を要求してくることがある。この場合の対応:

1. 追加調査を**ステップ 1-2 に戻って実施する** (例: `mcp__issuehunt__get_report_messages` / `get_report_notes` で過去報告の reply を読む、ステップ 2 のコードレベル検証で fix commit を特定する)
2. 調査結果が出たら判定が変わるかを再評価する。判定が変わった場合は Codex に再度セカンドオピニオンを依頼するか、結論が明確 (例: fix commit が特定できて duplicate 確定) なら Codex 再依頼を省略してよい
3. **追加調査の結果が出るまで Slack 投下を保留する** (ステップ 8 のルール)

ループの上限: 同一論点で 3 回以上 Codex に往復が発生する場合、論点が複雑で skill だけでは解決できない可能性が高い。PF チームへ「skill 側で結論を出せない論点が残っている」旨を明記して投下する。

Codex 未実施時の記載ルール:

- 未実施の事実は **内部メモ (ステップ 5) の末尾** に `【環境メモ】 Codex セカンドオピニオン未実施 (理由: cmux/tmux 外 / pane 起動失敗 / その他)` の 1 行で記録する
- Slack 投下メッセージ (ステップ 8) には **書かない**。Slack 上に「未実施」と書くと、ステップ 8 の出力構造ルール (Codex 出所明示禁止) との境界が曖昧になり、reporter / PF チームから見て「Codex を使ったのか使っていないのか」のメタ情報が混入する。内部メモは PF チーム閲覧専用なのでそこに留める

### 4. アクション決定

IssueHunt の「Other Actions」プルダウンには 10 種の正式アクションがある。skill の評価結果を IssueHunt のアクション + state にマッピングする。

| IssueHunt Action | 対応する state (`update_report_state`) | 使う場面 |
|------------------|----------------------------------------|---------|
| To Certify | `triaged` | 報奨金額の決裁待ち (PF チーム経由) |
| To Appraisal | `triaged` | Severity 査定中、追加情報待ち |
| To Fix | `triaged` | 修正対応必要、Engineering へ ticket 切る |
| To Review (Informative) | `informational` | hardening / 設定推奨で vuln ではない |
| To Review (Resolved) | `resolved` | 修正完了し再確認段階 |
| Close (Informative) | `informational` | hardening / 既知設計の確認、報奨対象外 |
| Close (Resolved) | `resolved` | 修正済み、報奨金支払い済み |
| Suspend | `unresolved` | 追加情報待ちで一時停止 |
| Request Re-evaluation | `triaged` | 報告者に再現手順の補強依頼 |
| Invalidate | `not_applicable` / `not_reproducible` / `out_of_scope` | 仕様通り / 再現不可 / スコープ外 |

評価結果 → 推奨アクションのマッピング (typical):

| skill の評価 | 推奨 IssueHunt action | state |
|--------------|----------------------|-------|
| 脆弱性ではない (仕様) | Invalidate | `not_applicable` |
| Out of Scope | Invalidate | `out_of_scope` |
| 再現できない | Invalidate | `not_reproducible` |
| Duplicate (過去 `triaged` / `resolved` で進行中) | Invalidate | `duplicate` |
| Duplicate (過去 `informational` / `not_applicable` で close 済み) | Close (Informative) | `informational` |
| Duplicate (過去 `resolved` だが regression 疑い) | To Fix | `triaged` |
| hardening / 設定推奨 | Close (Informative) または To Review (Informative) | `informational` |
| 修正対応必要 | To Fix | `triaged` |
| 報奨金確定 | To Certify | `triaged` (報奨後 `resolved`) |

Duplicate の 3 行はステップ 1 重複チェック表と対応している。重複チェック表で行が確定すれば、上記表もそれに従う (どちらか片方だけ参照する場面でも判断が一意になる)。

state 更新の実コマンド (PF チーム実行用):

```
mcp__issuehunt__update_report_state(reportId, state)
```

skill 側は state 値の提案までで、実更新は PF チームに委ねる。

#### canonical duplicate target の state 整合性確認

`Invalidate` + state `duplicate` を提案する場合、canonical duplicate target の state が実態と整合しているかを必ず確認する。triage 漏れで以下の不整合が残っているケースがある:

- 実装は fix 済みなのに canonical target の state が `unresolved` / `new` / `triaged` のまま → 報告者から見て「過去報告も処理されていないのに duplicate と言われている」状態
- canonical target が `unresolved` で内部 ticket とのリンクも切れている → fix 状況が外部から不明
- canonical target が `duplicate` でさらに上位の target を指している → 多段の duplicate チェーンを辿る必要

確認手順:

1. canonical target の `mcp__issuehunt__get_report(reportId)` で state を確認
2. ステップ 2 のコードレベル検証で実装側の fix 状況を確認
3. 不整合があれば内部メモの `【Engineering ハンドオフ】` 末尾に `【canonical target cleanup 依頼】` ブロックを追加:
   - 例: `#55 の state を unresolved → resolved に更新 (PR #19310, 2025-10-16 で fix 済み)`
4. Slack 投下メッセージにも同セクションを明記し、PF チームに本件 triage と合わせて cleanup を依頼する

### 5. 日本語内部メモ記入

`mcp__issuehunt__add_internal_note` で org 内のみ閲覧可能な日本語メモを残す。報告者には見えない。triage 判断の根拠・関連報告・engineering へのハンドオフ情報を書く。

テンプレート:

```
【判定】 {Informative / To Fix / Invalidate ...}
【Severity】 {Informational / Low / Medium / High / Critical}
【Priority】 {P1 / P2 / P3 / P4 / P5} (Bugcrowd VRT 1.18 baseline)
【VRT mapping】
- {Finding N (該当する場合)}: <VRT category path> (P<priority>)
- 代替マッピング (該当する場合): <alt path> (P<priority>)
【根拠】
- {1行サマリ}
- {重要な技術的論点}
- {Codex 指摘で採用した点があれば、出所を明示せずそのまま技術論点として書く}

【関連報告】
- #XXX: {関係性}
- #YYY: {関係性}

【Engineering ハンドオフ】
- 修正範囲: {サービス / リポ / コード位置}
- 修正優先度: {P1 / P2 / P3} (Engineering ticket 上の優先度、VRT Priority とは別軸)
- 確認ポイント: {互換性検証等}

【報奨金提案】 {額 / 該当なしの理由}

【返信ドラフトの所在】 Slack thread: {URL}
```

`【Priority】` は finding ごとに独立して付ける (1 レポート N findings の場合)。`【Severity】` は本邦運用ラベル、`【Priority】` は Bugcrowd VRT baseline で意味が違うので両方記載する。`【Engineering ハンドオフ】 修正優先度` は VRT Priority と紛らわしいため、エンジニアリングチームの内部 ticket 優先度であることを明示する。

skill 側はドラフトを `/tmp/bug-bounty-internal-note-{reportId}.md` に書き出すまでにとどめ、`add_internal_note` の実投稿は PF チームに委ねる。

### 6. 返信文作成

評価結果に基づいて英語の返信文を作成する。テンプレート:

#### 脆弱性ではない場合 (Not Applicable)

```
Thank you for your report.

After reviewing your submission, we have determined that this does not constitute a security vulnerability.

[技術的な説明 - なぜ脆弱性ではないか]

While we appreciate your interest in our security, this report does not qualify for a bounty reward as it describes intended platform functionality rather than a vulnerability.

Best regards,
WINTICKET Security Team
```

#### Informative / Hardening の場合

```
Thank you for the detailed report.

We have reviewed your submission and confirmed that the configuration state you observed is accurate. After review, we are classifying this report as Informative rather than as a separately rewardable vulnerability. Our reasoning:

1. [技術的な切り分け - なぜ hardening であって exploit ではないか]
2. [関連報告との関係 - 実害シナリオがそちらで扱われている等]
3. [VRT マッピングと program policy の言及]

No separate reward will be issued. Your recommendations have been forwarded to the engineering teams as input to our broader hardening work.

We appreciate the technical depth of your analysis.

Best regards,
WINTICKET Security Team
```

#### 修正対応する場合 (To Fix)

```
Thank you for your report.

We have reviewed your submission and confirmed the vulnerability. We are currently working on a fix.

[認識した問題の概要]

We will update you once the fix has been deployed.

Best regards,
WINTICKET Security Team
```

署名は `WINTICKET Security Team` 固定 (report 上の公式呼称)。triage 内部の引き渡し先 (PF チーム) と返信署名は別レイヤー。

### 7. 報奨金算定

報奨金が出るアクション (`To Fix` / `Close (Resolved)` 等) では報奨金額を算定する。

基本ロジック:

1. 基本額 = レポートの `脆弱性種類 × CVSS(v4.0) by researcher` に対応する額 (program 設定の表に従う)
2. 上限チェック = 影響度ベース。基本額が上限を超える場合は上限額で支払う

組織固有の支払額表・上限額は `${CLAUDE_SKILL_DIR}/SKILL.local.md` 参照。具体額はそちらに書き、本ファイルには書かない。

報奨金が出ないアクション (`Close (Informative)` / `Invalidate` / `Close (Duplicate)` / `To Review (Informative)`) の場合は影響度判定・上限額算定をスキップしてよい。内部メモの `【報奨金提案】` には「該当なし (Close (Informative) のため)」のような 1 行で済ませる。

算定結果は内部メモ (ステップ 5) の `【報奨金提案】` セクションに記入。実支払いは PF チームが `mcp__issuehunt__award_reward` で実行する。

### 8. 出力・Slack 投下

最終的な triage 結果を Slack スレッド (Bug Bounty Notify チャネル) に投下する。

#### 投下タイミング

**triage 判定が確定した後、1 通にまとめて投下する**。中間判定 (例: 「内部 ticket scope 次第で Informative or Duplicate」「Codex 追加調査の結果待ち」) の段階では投下しない。

中間状態で投下すると、追加調査後の続報を追記する形になり、最終的に PF チームが読みづらい複数メッセージのスレッドが残る。実際にスレッドが混乱して「全削除→再投下」の手戻りが発生する。

例外: 緊急性が高く PF チームの即時判断が必要な場合のみ、中間判定で投下してよい (例: critical 脆弱性で production の即時 mitigation が必要、PF への escalation を急ぐ)。この場合は本文冒頭に `:warning: 中間判定、追加調査中` を明記する。

#### 投下内容 (1 メッセージにまとめる)

1. トリアージサマリ (Severity / Priority (Bugcrowd VRT 1.18) / Disposition / 関連報告)
2. 評価サマリ (箇条書き)
3. 実装側コードレベル検証結果 (該当する場合、commit hash / PR / 行番号を引用)
4. VRT mapping (finding ごとに `<VRT path> (P<priority>)` 形式、複数該当する場合は併記)
5. 推奨 IssueHunt アクション + state
6. canonical duplicate target の state cleanup 依頼 (該当する場合)
7. 報奨金提案額 + 根拠
8. Engineering ハンドオフ (PoC アカウント削除 / 中長期 hardening / 追加検証論点)
9. 英語返信ドラフト本文 (コードブロック)
10. 内部メモのドラフト (コードブロック、`/tmp/` パス参照ではなく本文を貼る)
11. 末尾: `最終判断・送信は PF チームでお願いします。`

トーンルール ([[feedback-slack-post-tone]]):
- 紅莉栖キャラ口調 (「〜わ」「〜じゃない」) は持ち込まない
- 中立業務トーン
- Markdown テーブルは Slack で崩れるので箇条書き + 絵文字で構造化

出力構造ルール:
- Claude Code の評価と Codex の評価を分けて書かない。両者の論点をマージして単一の triage 結論として提示する
- 「Codex (gpt-5.4) でセカンドオピニオン取得済み」「Codex の指摘で〜」のような出所明示は不要。最終的な triage 結論として読み手に提示できればよい
- 裏取りした外部参照 (Bugcrowd VRT 公式等) のリンクは「判定根拠」として残してよい (これは出所ではなく外部権威への参照)

destructive 系操作 (スレッド削除・編集) を依頼された場合は [[feedback-slack-destructive-ops]] に従い、先に `ToolSearch` で対応 tool 有無を確認する。

ローカルファイル出力:
- `/tmp/bug-bounty-response-{reportId}.txt`: 英語返信本文
- `/tmp/bug-bounty-internal-note-{reportId}.md`: 日本語内部メモ

これらはあくまでローカル参照用。PF チームから見える Slack スレッドに本文を貼り出すのが主経路。

## よくあるパターンと対応

| 報告内容 | 脅威レベル | VRT Priority | 対応 | 理由 |
|---------|-----------|--------------|------|------|
| Firebase API Key 公開 | Informational | P5 | Close (Informative) | Not Applicable (client 埋め込み前提) |
| Datadog Client Token 公開 | Informational | P5 | Close (Informative) | Not Applicable (pub* は client 配布前提) |
| Sentry DSN 公開 | Informational | P5 | Close (Informative) | Not Applicable |
| ユーザー列挙 (標準機能) | Low/Informational | P4-P5 | Close (Informative) | Not Applicable |
| 古いライブラリバージョン (悪用不可) | Informational | P5 | Close (Informative) | Not Applicable |
| Firebase config dump (`getRecaptchaConfig` 等) | Informational | P5 | Close (Informative) | hardening recommendation |
| Self-XSS (custom header reflection) | Informational | P5 | Close (Informative) | Self-only、cache 非伝播 |
| CORS 設定ミス (実害あり) | Medium〜High | P3-P2 | To Fix | - |
| 認証バイパス | High〜Critical | P2-P1 | To Fix | - |

## 注意事項

- 最終判断・state 更新・内部メモ投稿・報奨金支払いは PF チームが実施する
- skill 側は提案ドラフトまでで、IssueHunt MCP の write 系 (`update_report_state` / `add_internal_note` / `award_reward` / `post_message`) を勝手に呼ばない
- Codex の確認は「リスク棚卸完了」であり、出荷基準ではない
- 不明な場合は PF チームに相談

## Gotchas

- IssueHunt `list_reports.search` は厳密一致寄り。重複チェックは全件取得が確実 ([[issuehunt-search-quirks]])
- `Close (Informative)` と `To Review (Informative)` の違い: 前者は最終 close、後者は再評価ステージ
- `Invalidate` の state 3 種 (`not_applicable` / `not_reproducible` / `out_of_scope`) の使い分けに注意
