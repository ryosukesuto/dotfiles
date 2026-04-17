---
title: Reviewer I/O Contract
version: 1
---

## 概要

全てのreviewer（baseline / specialist）が従う入出力契約。この契約に従わない出力は finding-normalizer で drop される。

## 入力

reviewerは以下2つを受け取る。

### 1. review bundle（全reviewer共通）

パス参照で渡される。内容は `schemas/bundle.schema.json` に準拠。

### 2. review_slice（reviewer毎）

bundle内の `review_slices[reviewer_id]` を展開したもの。構造:

```json
[
  {
    "repo": "server",
    "path": "api/payment/service.go",
    "hunk_ranges": [{"start": 123, "end": 145}],
    "reason": "決済トランザクション境界の変更"
  }
]
```

`hunk_ranges` の意味:

- 配列あり: 指定行範囲のみ参照対象。範囲外は読まない
- 配列なし（省略）: ファイル全体が参照対象（小さい設定ファイル・新規追加ファイル等）
- 空配列 `[]` は禁止（意味が曖昧）

reviewerはこの範囲 + `relevant_snippets` + 必要に応じて該当ファイルのRead で完結する。repo全探索は禁止。

## 出力

ラッパーオブジェクトを返す。`findings` は `schemas/finding.schema.json` に準拠した finding オブジェクトの配列。

### 出力形式（唯一）

```json
{
  "reviewer_id": "codex-baseline",
  "findings": [
    { /* finding object */ },
    { /* finding object */ }
  ],
  "meta": {
    "tokens_used": 12345,
    "wall_time_ms": 8200,
    "slice_count": 3,
    "dropped_candidates": 2
  }
}
```

この形式が唯一の契約。`findings` 配列のみを裸で返す形式は禁止（orchestrator/normalizerの受け口を固定するため）。

### 出力制約

- `findings` は最大件数制限あり（severity別）:
  - `must-fix`: 最大5件
  - `should-fix`: 最大10件
  - `watch`: 最大15件
- 最大件数を超える候補が出た場合、`meta.dropped_candidates` に件数を記録し、reviewer側で severity + confidence でソートして上位のみ採用

### 品質要件

1. `evidence.excerpt` は必須。空や省略は drop 対象
2. `evidence.location` はファイル実在、行範囲が1以上、end >= start
3. `claim` と `why_it_matters` は別々に書く（同じ内容の言い換え禁止）
4. `fix_hint` は `must-fix` では推奨、`watch` では任意
5. 打消し文（「ただし実際には問題にならない」等）は禁止

### entity_key 生成規則（canonical）

全 reviewer がこの規則に従う。normalizer の caller/callee dedupe はこの一貫性に依存する。

- 基本: `{repo}:{path}:{symbol}`
  - `symbol` はトップレベル関数名・メソッド名・型名・RPC名・env var名など、一意に識別できる名前
- symbol 不明時: `{repo}:{path}`
- consumer 側の finding（cross-repo agent が発行する場合）:
  - 発見したconsumer側のlocation（repo:path:symbol）ではなく、triage の `must_check_interfaces[].source_repo:source_path:source_symbol` を使う
  - 理由: 同一インターフェース不整合を caller/callee で別物扱いしないため
  - consumer側の具体位置は `related_locations[]` に入れる

### normalizer 側の runtime validation（schema で表現できない制約）

normalizer は受け取った finding に対して以下を実行する:

- `lines.end >= lines.start`（`evidence.location.lines` / `related_locations[].lines` も同様）
- `finding_id` の prefix が `source_reviewer` と一致すること
- `entity_key` のフォーマット正しさ（`{repo}:{path}(:{symbol})?`）
- `evidence.excerpt` が空文字でないこと

いずれかに違反した finding は drop（または quarantine ログ）。

## reviewer別のプロンプトテンプレ

### baseline reviewer 共通

プロンプトに以下を丸ごと埋め込む。

```
あなたは reviewer_id="{reviewer_id}" として動作します。

入力:
- bundle: {bundle_path}
- review_slice: {slice_path}

タスク:
1. slice で指定されたファイル/hunkを読む
2. bundle.interface_changes と risk_tags を参照し、変更の影響範囲を把握する
3. 担当観点で findings を列挙する
4. 以下の出力フォーマットに従って出力する

担当観点:
{observation_points}

## 出力フォーマット（厳守）

JSONのみ出力すること。前置き・説明文・サマリ・まとめは一切禁止。

```json
{
  "reviewer_id": "{reviewer_id}",
  "findings": [
    {
      "finding_id": "{reviewer_id}-a1b2c3",
      "source_reviewer": "{reviewer_id}",
      "severity": "must-fix",
      "confidence": 0.85,
      "issue_type": "concurrency",
      "entity_key": "{repo}:{file_path}:{symbol_name}",
      "repo": "{repo_name}",
      "file": "{repo_relative_path}",
      "lines": {"start": 42, "end": 55},
      "related_locations": [],
      "claim": "問題の主張を1行で（200文字以内）",
      "evidence": {
        "evidence_type": "code",
        "excerpt": "実際のコード抜粋（必須・空禁止）",
        "location": {
          "repo": "{repo_name}",
          "file": "{repo_relative_path}",
          "lines": {"start": 42, "end": 45}
        }
      },
      "why_it_matters": "なぜ問題か（claim の言い換え禁止）",
      "fix_hint": "修正方法の提案"
    }
  ],
  "meta": {
    "tokens_used": 0,
    "wall_time_ms": 0,
    "slice_count": 1,
    "dropped_candidates": 0
  }
}
```

## フィールド仕様（必読）

| フィールド | 型 | 必須 | 値の制約 |
|-----------|-----|------|---------|
| finding_id | string | ✓ | `{reviewer_id}-` + 6文字の識別子 |
| source_reviewer | string | ✓ | 上の reviewer_id と同じ値 |
| severity | string | ✓ | `must-fix` / `should-fix` / `watch` のいずれか |
| confidence | number | ✓ | 0.00〜1.00 の小数 |
| issue_type | string | ✓ | `concurrency` / `security` / `contract` / `perf` / `error-handling` / `naming` / `test-coverage` / `config` / `data-migration` / `iam` / `observability` / `other` のいずれか |
| entity_key | string | ✓ | `{repo}:{path}:{symbol}` 形式（symbol不明時は `{repo}:{path}`） |
| repo | string | ✓ | リポジトリ名 |
| file | string | ✓ | リポジトリルートからの相対パス |
| lines | object | ✓ | `{"start": N, "end": N}`（整数、end >= start） |
| claim | string | ✓ | 問題の1行主張（200文字以内） |
| evidence.evidence_type | string | ✓ | `diff` / `code` / `config` / `log` / `static-analysis` のいずれか |
| evidence.excerpt | string | ✓ | 空文字・省略禁止。実際のコード/設定を引用 |
| evidence.location | object | ✓ | `{repo, file, lines}` |
| why_it_matters | string | ✓ | claim の言い換え不可。影響・リスクを記述 |
| fix_hint | string | - | 任意。must-fix では推奨 |

## 禁止事項

- `category` / `title` / `description` / `suggestion` といった独自フィールド名の使用禁止（上記フィールド名のみ使用すること）
- evidence.excerpt を空にすること禁止
- finding の前後に自由文を書くこと禁止
- must-fix は 5件、should-fix は 10件、watch は 15件を上限とする

## 制約

- review_slice の範囲外は読まない（bundle.symbol_index にある場合のみ例外）
```

### observation_points（reviewer別）

| reviewer_id | 観点 |
|-------------|------|
| `codex-baseline` | 実装詳細、エッジケース（境界値、空入力、同時実行、権限不足） |
| `opus-baseline` | 設計意図、影響範囲、APIコントラクト整合性 |
| `review-server-pr` | クリーンアーキテクチャ、サーバー側規約、DBトランザクション |
| `security-review-opus` | 認証/認可、入力検証、シークレット露出、権限昇格、監査ログ |
| `security-review-codex` | 同上（cross-validation）+ Semgrep/gosec結果の解釈 |
| `cross-repo` | インターフェース変更のconsumer側影響（pinpointクエリのみ回答） |

## バージョニング

この契約の破壊的変更は `version` をインクリメントする。reviewer側も受け入れ可能なバージョンを明示する。
