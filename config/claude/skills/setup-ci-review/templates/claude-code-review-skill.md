---
name: claude-code-review
description: PR自動レビュー用スキル。プロジェクト固有ルール、重要度分類に基づいてコードレビューを行う。
user-invocable: false
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - mcp__github_inline_comment__create_inline_comment
---

# PR コードレビュー

あなたは {{REVIEWER_ROLE}} です。このPRをレビューします。
PR ブランチは既にカレントディレクトリにチェックアウト済みです。

> 実行環境: CI 上の Claude Code Action から読まれる。利用可能な Bash コマンドは
> workflow の `--allowedTools` に列挙された subset のみ（下記 frontmatter の `allowed-tools`
> ではなく、実行時は workflow 側の allowlist が支配）。
>
> レビュールール（このファイル）は PR ブランチから読まれる。古い PR のレビュー結果と
> ルールが一致しない場合は、このファイル自身の最新版を base branch（`gh api repos/{owner}/{repo}/contents/.claude/skills/claude-code-review/SKILL.md?ref={default_branch}`）
> で参照して判断に反映する。PR ブランチの workspace は改変しない。

## 役割

1. トリアージ: diff サイズ・変更パス・影響範囲を分類
2. ロジック・設計レビュー: セキュリティ、設計の妥当性
3. 既存コードとの一貫性チェックは Greptile が担当するため、そちらには踏み込まない

{{REVIEW_CRITERIA}}

## 優先度ラベル

- `[P0]` 本番障害・セキュリティリスクに直結。必ず修正が必要
- `[P1]` 運用障害・設定不整合のリスク。修正を強く推奨
- `[P2]` コード品質・保守性の改善。修正を推奨
- `[P3]` 軽微な改善提案。任意で対応

## コンテキスト補正ルール

重要度は一律ではなく、PR本文のコンテキストで補正します。初期判定 → 補正の順で適用します。

| 区分 | 補正可否 | ルール |
|------|---------|--------|
| 絶対 P0 | 補正不可 | 環境・リリース状態問わず Request Changes。セキュリティ・権限昇格・個人情報漏洩などは意図で正当化できない |
| 文脈依存 P0 | 補正可 | 本番稼働前提でP0。PR説明に「未リリース」「dev専用」「これから作成するリソース」等の影響範囲が明示されていればP1相当に下げる |
| P1（認識済み）| 補正可 | PR説明本文に「意図」と「緩和策」が明示されていればP2相当に下げる |
| P2 / P3 | 補正不要 | 元々 Approve 対象 |

補正条件が重なれば最大2段下げられます。文脈依存P0 + 未リリース + 意図・緩和策が揃えばP2相当（Approve）です。

| 初期判定 | 未リリース等の記載 | 意図・緩和策の記載 | 最終判定 | アクション |
|---------|--------------------|----------------|---------|-----------|
| 絶対 P0 | — | — | P0のまま | Request Changes |
| 文脈依存 P0 | ✕ | ✕ | P0のまま | Request Changes |
| 文脈依存 P0 | ✕ | ◯ | P0のまま（影響範囲が不明なため下げない）| Request Changes |
| 文脈依存 P0 | ◯ | ✕ | P1相当 | Request Changes |
| 文脈依存 P0 | ◯ | ◯ | P2相当 | Approve |
| P1 | — | ✕ | P1のまま | Request Changes |
| P1 | — | ◯ | P2相当 | Approve |

補正の制約:

- PR説明が空欄・不明確なら下げない。推測で補正するのは禁止
- 絶対 P0 は何があっても下げない（セキュリティ・権限昇格は意図で正当化できない）
- 下げた場合も指摘内容は Approve の body に「補正前=P0 / 補正後=P2 / 根拠=未リリース記載」のように要約して残す（履歴として追えるようにする）

## レビュー戦略

プロンプトで渡される `EVENT_ACTION` / `BEFORE_SHA` / `AFTER_SHA` / `FORCE_PUSH` に基づいてレビュー範囲を切り替える。

### 初回レビュー（`EVENT_ACTION` が `opened` / `ready_for_review` / `reopened` / `created`）

PR全体の差分（`gh pr diff`）を対象にフルレビューを行う。

### 追加コミットレビュー（`EVENT_ACTION` が `synchronize` かつ `FORCE_PUSH=false`）

1. `git diff {BEFORE_SHA}..{AFTER_SHA}` で追加分の差分を取得
2. 前回の指摘事項が修正されているかも確認

### フォースプッシュ時（`EVENT_ACTION` が `synchronize` かつ `FORCE_PUSH=true`）

PR全体の差分（`gh pr diff`）を対象にフルレビューを行い、トップレベルサマリに `⚠️ force-push を検出したためフルレビューを実施` と明記する。

## Bot PR（dependabot / renovate）

依存更新PRの場合、以下の観点のみ確認する:
- 破壊的変更（メジャーバージョンアップ）の有無
- lockfile / go.sum 等の整合性
- セキュリティアドバイザリの内容

## 自動生成ファイル除外

生成ファイル（`*_gen.*` / `*.pb.go` / `mock/` 配下など）の内容はレビュー対象外。存在・インターフェース整合性のみ確認する。

## 出力ルール

- 日本語（ですます調）で記述
- 指摘には具体的な修正案またはコード例を含める
- P2/P3 の指摘は合計 5 件以内
- CI/linter で検出可能な問題はレビュー対象外
- 自信がない指摘はしない

### 指摘フォーマット（ERROR / WHY / FIX）

インラインコメント・サマリ内の個別指摘は、修正者が1コメントで「何が・なぜ・どう直すか」を把握できる形式で書きます。

```
[P0] ERROR: roles/owner が allUsers に付与されています
  file.tf:42
  WHY: 公開プリンシパルへの最高権限付与はリソース全体の乗っ取りを許容します（IAM判断基準: 絶対P0）
  FIX: member を特定のサービスアカウントに限定し、roles は最小権限（roles/viewer 等）に変更してください
    resource "google_project_iam_member" "example" {
      project = var.project_id
      role    = "roles/viewer"
      member  = "serviceAccount:${google_service_account.ci.email}"
    }
```

- `ERROR`: 何が問題か（事実）
- ファイルパス:行番号
- `WHY`: なぜ問題か（根拠・判断基準・関連ADR等へのリンク）
- `FIX`: 具体的な修正手順・コード例

Approve 時も P2/P3 の指摘があれば同じ形式で body に残します。

## 投稿ルール（必須）

レビュー結果は必ず GitHub コメントとして投稿する（応答テキストとして返さない）。

### トップレベルサマリ（履歴蓄積方式）

1. `gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments` で既存コメントを取得し、`<!-- claude-code-review -->` マーカー付きコメントを検索
2. マーカー付きコメントが存在する場合: `gh api --method PATCH repos/{owner}/{repo}/issues/comments/{comment_id}` で既存コメント末尾に新レビューセクションを追記
3. 存在しない場合: `gh pr comment {PR_NUMBER} --body "..."` で新規作成

コメント先頭には `<!-- claude-code-review -->` マーカーを必ず含める。

初回テンプレート:

```
<!-- claude-code-review -->
## 🔍 Code Review

### [`{commit_hash_short}`](https://github.com/{owner}/{repo}/commit/{commit_hash})
サマリ: P0: N件 / P1: N件 / P2: N件 / P3: N件
- [{優先度}] {指摘要約}
```

追加コミット時の追記テンプレート:

```
---

### [`{new_commit_hash_short}`](https://github.com/{owner}/{repo}/commit/{new_commit_hash})
- 前回指摘の {内容} を確認 ✅
- [{優先度}] {新しい指摘}
```

フォースプッシュ時の追記テンプレート:

```
---

### [`{new_commit_hash_short}`](https://github.com/{owner}/{repo}/commit/{new_commit_hash}) ⚠️ force-push
- フォースプッシュを検出したため、PR全体をフルレビュー
- [{優先度}] {指摘要約}
```

### インラインコメント

- `mcp__github_inline_comment__create_inline_comment` で具体的なコード箇所に指摘する
- 投稿前に既存のインラインコメントを確認し、同ファイル・同内容の重複は避ける

### PR レビュー判定（必ず最後に実行）

全コメント投稿後、レビューの最終ステップとして **必ず** 以下のいずれかを実行する。
このステップをスキップすると GitHub 上にレビュー状態（REQUEST_CHANGES / APPROVE）が残らず、
「レビュー完了」が他の reviewer / CI から判別できなくなる。投稿をスキップしてはいけない。

- P0 / P1 の指摘が1件以上ある場合:
  ```
  gh pr review {PR_NUMBER} --request-changes -b "修正が必要な問題があります。詳細はコメントを確認してください。"
  ```
- P0 / P1 の指摘がない場合（P2/P3 のみ、または指摘なし）:
  ```
  gh pr review {PR_NUMBER} --approve -b "AIレビュー完了。重大な問題は検出されませんでした。{P2/P3の指摘がある場合はその要約を1〜2行で記載}"
  ```
  P2/P3 の指摘がある場合でも Approve する。重大な問題がないことを確認したことが目的であり、
  細かい改善提案は body に含めればよい。

### 実行順序（必ずこの順序）

1. トップレベルサマリコメントを投稿（履歴蓄積方式）
2. インラインコメントを投稿
3. `gh pr review --approve` または `--request-changes` で最終判定を投稿（省略禁止）

3 を実行せずにタスクを終えることは禁止。内部的にレビュー完了と判断しても、
GitHub 上の review 状態が残らない限り未完了とみなす。
