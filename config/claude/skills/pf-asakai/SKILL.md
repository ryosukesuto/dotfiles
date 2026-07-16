---
name: pf-asakai
description: Platform Engineering朝会の進捗共有まとめ（前日やったこと/今日やること/共有）を生成する。「朝会」「朝会まとめ」「朝会分出して」「asakai」「standup」「進捗共有まとめ」等で起動。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - ToolSearch
  - mcp__linear-decent__list_issues
  - mcp__linear-decent__get_issue
  - mcp__linear-decent__list_comments
---

# /pf-asakai - 朝会進捗共有まとめの生成

朝会で共有する「前日やったこと / 今日やること / 共有」の3見出し箇条書きを、朝会メモ・デイリーノート・GitHub・Linearの実績から生成する。

## 実行手順

### 1. ローカル設定を読む

情報ソースのパス・対象org・Linear team・除外ルールは、このSKILL.mdと同じディレクトリの `SKILL.local.md` に定義されている。最初に読み込む。サービス固有の値を本ファイルに書かないのは、publicリポジトリに社内情報を含めないため。

このskillはClaude CodeとCodexの両方から使う（`~/.claude/skills/pf-asakai` と `~/.agents/skills/pf-asakai` に同一ディレクトリがリンクされている）。Linear MCPのserver名など実行環境ごとの差分はSKILL.local.mdに記載がある。

### 2. 前提確認

```bash
date "+%Y-%m-%d (%a) %H:%M"   # 「前日」の基準日を決める
gh auth status                 # アクティブアカウント確認
```

ghのアクティブアカウントがSKILL.local.mdで指定したものと違う場合は `gh auth switch` で切り替える。別アカウントのままだとorg権限がなく、404や空の検索結果が返って「実績なし」と誤判定する。

### 3. 情報収集（並列実行）

SKILL.local.mdのソース定義に従い、以下を並列で確認する。

1. 直近の朝会メモ（自分の節の「本日」欄が前日実績の候補になる）
2. 前日のデイリーノート
3. GitHub実績（自分のPR・レビューしたPR）
4. Linear（担当Issueの直近更新。`updatedAt: -P3D` 程度で引き、実績の裏取りが必要ならコメント履歴も見る）

### 4. 実績の帰属判定

- GitHub / LinearのタイムスタンプはUTC。JSTに変換してから日付の帰属を決める
- 「前日」は原則、暦日の前営業日。直近の朝会メモがそれより古い場合は「前回朝会以降」をカバー範囲に広げるか判断し、どちらの解釈で作ったかを提示時に明記する
- SKILL.local.mdの除外ルールに該当する作業は含めない

### 5. 「今日やること」の組み立て

LinearのIn Progress Issueと、期日が当日・期日超過のIssueから拾う。期日超過でも自分以外の対応待ち（レビュー待ち等）でブロックされているものは「今日やること」ではなく「共有」の依頼事項に回す。

### 6. 出力

以下のフォーマットでコードブロックに入れて提示する。朝会ツールにそのまま貼る用途で、リンクは表示されず冗長になるだけなので入れない。

```
- 前日やったこと
    - {1行の短文}
- 今日やること
    - {1行の短文}
- 共有
    - {不在予定・依頼事項。なければ見出しだけ残す}
```

- Issue管理ツールのURL・Issue IDは書かない。PR番号は「PR #77」「#77」程度の短い参照のみ可
- 各項目は1行の短い文。太字・リンク・補足説明なし
- コードブロックの後に、作成の前提（「前日」のカバー範囲の解釈・除外した作業・各項目の根拠）を添えて、ユーザーが調整できるようにする

## Gotchas

- 朝会メモは毎日あるとは限らない（週明けや休会で欠ける）。前日分がなくても実績なしと判断せず、GitHub / Linearから直接拾う
- デイリーノートの深夜帯（0〜2時台）のエントリは前日夜の作業であることが多い。当日実績に数えない
- デイリーノートには対象外プロジェクトの作業が混在する。除外はorg名・Issue prefixで機械的に判定する（SKILL.local.md参照）
- LinearのJST 0時台のupdatedAtはcycle自動処理のことがある。実績の根拠にはコメント投稿・状態遷移・PRなど人間の操作を使う
- Linear MCPのworkspaceを間違えない。server名と対象workspaceの対応はSKILL.local.mdの定義に従う（別workspaceのserverで検索すると0件になり「実績なし」と誤判定する）
