---
description: バイブコーディングCodexレビュー - design/plans/PRの観点別レビュー
---

# /vibe-review - Codexレビュー依頼

design.md、plans.md、またはPRをCodexにレビュー依頼します。

## レビュー対象の自動判定

以下の優先順位で対象を判定：

1. PRが存在する場合 → PRレビュー
2. plans.md が存在する場合 → plans.mdレビュー
3. design.md が存在する場合 → design.mdレビュー

手動で指定する場合は引数を使用：
- `/vibe-review design` - design.mdをレビュー
- `/vibe-review plan` - plans.mdをレビュー
- `/vibe-review pr` - PRをレビュー

## レビュールール

### 共通ルール
- レビュー往復は基本1回まで
- Major issueがある場合のみ最大2回まで許容
- 完璧化ではなくリスク洗い出しに集中

### Major / Minor の判定基準

| 分類 | 内容 | 対応 |
|------|------|------|
| Major | 目的未達成、セキュリティリスク、設計矛盾、大規模手戻り | 修正必須 |
| Minor | 曖昧な表現、命名改善、説明不足、粒度調整 | 修正任意 |

## 実行手順

### design.md レビュー

```bash
codex exec "design.mdをレビューしてください。

## レビュー対象
$(cat design.md)

## コンテキスト
[ここにProject Contextを挿入]

## レビュー観点
1. 目的整合性 - ゴールと提案が一致しているか
2. 技術的妥当性 - 実現可能か、適切なアプローチか
3. 非機能要件 - 性能・信頼性・セキュリティ・運用性
4. 影響範囲とリスク - 見落としがないか
5. 設計の一貫性とシンプルさ

## 出力形式
各観点ごとに:
- Good: 良い点
- Concern: 懸念点（Major / Minor を明記）
- Suggestion: 改善提案

最後に:
- Major: n件
- Minor: n件
- Status: 'OK to proceed with minor fixes' または 'Not ready (Major issues present)'
"
```

### plans.md レビュー

```bash
codex exec "plans.mdをレビューしてください。

## レビュー対象
$(cat plans.md)

## 対応するdesign.md
$(cat design.md)

## レビュー観点
1. 設計（design.md）との整合性
2. 変更範囲の妥当性
3. タスク分解に抜け漏れがないか
4. マイグレーション / ロールバック手順が現実的か
5. リスクと対策が実装レベルで十分か

## 出力形式
各観点ごとに:
- Good: 良い点
- Concern: 懸念点（Major / Minor を明記）
- Suggestion: 改善提案

最後に:
- Major: n件
- Minor: n件
- Status: 'OK to proceed with minor fixes' または 'Not ready (Major issues present)'
"
```

### PRレビュー

PRレビューは `/review-pr` を実行し、結果をバイブコーディング形式に変換します。

#### ステップ1: /review-pr を実行

```bash
# /review-pr コマンドを実行してP0-P3形式のレビュー結果を取得
```

#### ステップ2: 結果をMajor/Minor形式に変換

| review-pr | バイブコーディング | 対応 |
|-----------|-------------------|------|
| P0 (Blocking) | Major | 修正必須 |
| P1 (Urgent) | Major | 修正必須 |
| P2 (Normal) | Minor | 修正任意（人間判断） |
| P3 (Low) | Minor | 修正任意（人間判断） |

#### ステップ3: サマリを作成

```markdown
## PRレビュー結果サマリ

### ステータス
- Major: X件（P0: a件、P1: b件）
- Minor: Y件（P2: c件、P3: d件）
- 判定: [OK to proceed / Not ready]

### 重要な注意
CodexのOKは「リスク棚卸完了」であり、マージ基準ではありません。
最終的なマージ判断は人間が行います。

### Major Issues（修正必須）
1. [P0/P1] 問題の内容
   - 影響: ...
   - 修正案: ...

### Minor Issues（修正任意 - 人間が判断）
1. [P2/P3] 改善提案
   - 提案: ...
```

## レビュー結果の処理

### OK to proceed with minor fixes の場合

1. Minor指摘は任意で対応
2. 次のフェーズへ進む
   - design.md → `/vibe-plan` で plans.md 作成
   - plans.md → 実装開始

### Not ready (Major issues present) の場合

1. Major指摘を修正
2. 再度 `/vibe-review` を実行（最大2回まで）
3. 2回目もMajorがある場合は人間に相談

## 出力物

Codexからのレビュー結果を整理して提示：

```markdown
## レビュー結果サマリ

### ステータス
- Major: X件
- Minor: Y件
- 判定: [OK to proceed / Not ready]

### Major Issues（修正必須）
1. [観点] 問題の内容
   - 修正案: ...

### Minor Issues（修正任意）
1. [観点] 改善提案
   - 提案: ...

### Good Points
- ...
```

## 次のステップ

| 対象 | OKの場合 | NGの場合 |
|------|----------|----------|
| design.md | `/vibe-plan` で plans.md 作成 | Major修正後に再レビュー |
| plans.md | 実装開始 | Major修正後に再レビュー |
| PR | 人間がマージ判断 | Major修正後に再レビュー |

## 人間の判断ポイント

バイブコーディングでは、以下のポイントで必ず人間が判断します：

1. **design.md OK後**: 方針確認 - この方向で進めてよいか
2. **plans.md OK後**: 計画承認 - この計画で実装を開始してよいか
3. **PR OK後**: マージ判断 - 本番に入れてよいか

CodexのOKは「リスク棚卸完了」を意味します。
「地雷がありそう」は教えてくれますが、「踏んでもいいか」は人間が決めます。
