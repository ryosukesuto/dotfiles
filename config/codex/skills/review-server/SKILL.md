---
name: review-server
description: Codex版review-prのspecialist。WinTicket/serverのPRやdiffをクリーンアーキテクチャ、コーディング規約、DBトランザクション、クロスリポジトリ整合性の観点でレビューする。「serverレビュー」「review-server」「WinTicket/server review」等で起動。
---

# review-server - Codex specialist review

WinTicket/serverの変更を、プロジェクト固有ルールとクロスリポジトリ整合性の観点でレビューする。Codex自身が主レビューワーなので、別Codex paneやClaude Agentは起動しない。

## 実行原則

- Codex版 `review-pr` のspecialist promptから呼ばれた場合は、親promptの出力形式を優先する。JSONのみを求められたらJSONのみ返す。
- 直接呼び出された場合は、このskillのMarkdown出力形式に従う。
- 技術的主張はdiff、既存コード、公式ドキュメント、またはリポジトリ内ルールで裏取りする。未確認のP0は禁止。
- 既存レビューコメントを確認し、重複指摘を避ける。
- `*_gen.go`, `*.pb.go`, `mock/` 配下の自動生成内容は原則レビュー対象外にする。ただし生成物の更新漏れやinterface整合性は確認する。

## ルール読み込み

必要時だけ読む。Codex fork内のファイルを優先する。

- `server-rules.md`: server固有のアーキテクチャ、命名、Spanner、proto、ログ規約
- `cross-repo-rules.md`: server-config / ops 連動観点
- `context.local.md`: 環境固有の非公開情報。存在する場合のみ読み、公開出力に具体値を出さない
- `reference.md`: 直接呼び出し時の出力フォーマット

## レビュー手順

1. PR情報とdiffを取得する:
   ```bash
   gh pr view --comments
   gh pr diff
   gh pr checks
   ```
2. 既存レビューコメントを確認する:
   ```bash
   gh api "repos/{owner}/{repo}/pulls/$(gh pr view --json number -q .number)/comments" \
     --jq '.[] | "[\(.user.login)] \(.path):\(.original_line // .line) - \(.body[0:200])"'
   ```
3. 変更スコープを分類する:
   - `gateway`, `admin`: OpenAPI、レスポンス変換、ビジネスロジック混入
   - `broker`: 決済、Spannerトランザクション、金額計算
   - `keirin`, `autorace`, `keiba`: ドメインロジック、外部システム連携
   - `user`: 認証・認可、個人情報
   - `messenger`: 通知、Pub/Sub、冪等性
   - `proto`: 破壊的変更、フィールド番号、生成物
   - 共通パッケージ: 全サービス影響、既存呼び出し元
4. `server-rules.md` を必要箇所だけ参照し、P0-P3で指摘を抽出する。
5. flags / proto / Spanner / Secret / Pub/Sub / ServiceAccount に関わる変更なら `cross-repo-rules.md` を適用する。
6. 直接呼び出しでは `reference.md` の出力フォーマットで統合レビューを返す。

## 優先度

| 優先度 | 内容 | server固有の例 |
| --- | --- | --- |
| P0 | マージ前に必須 | 決済金額ミス、認証バイパス、Spannerデッドロック誘発、proto破壊的変更 |
| P1 | 強く修正推奨 | N+1、errgroup未使用の並行処理、エラーラップ漏れ、クロスリポ整合性 |
| P2 | 対応推奨 | 命名規約、テスト不足、責務境界、capacity未指定 |
| P3 | 任意改善 | ログメッセージ、コメント、軽微な読みやすさ |

## Reader Testing

300行以上のPRで、ユーザーが明示的に「subagentで」「並列で」と依頼した場合のみ、Codex subagentにdiff-onlyレビューを委譲する。明示がない場合は、自分でPR説明を閉じたdiff-onlyパスとして同じ観点を実行する。

観点:

- 変更の意図が不明確な箇所
- テストで検証されていないエッジケース
- 暗黙の前提に依存している箇所
- クリーンアーキテクチャの依存方向違反

## Gotchas

- `goimports` / `gofmt` / `buf lint` / `custom-gcl` で検出できる整形・lintだけの指摘は出さない。
- server-config / ops 側確認が必要な場合、見つからないことを即P0にしない。該当repoのローカル有無と検索範囲を明示する。
- 既存コメントが同じ問題を指摘済みなら、重複投稿せず「既存指摘に同意」または「補足」に留める。
