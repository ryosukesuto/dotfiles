---
name: create-skill
description: 新しいSkillを作成する。「Skill作って」「スキル作成」等で起動。
argument-hint: "[skill-name]"
user-invocable: true
allowed-tools:
  - Bash(ls:*)
  - Bash(mkdir:*)
  - Read
  - Write
  - Glob
---

# /create-skill - Skill作成ガイド

新しいSkillを品質基準に沿って作成する。

## 実行手順

### 1. 要件整理

以下を確認してから作成を開始する:

- Skill名（kebab-case）
- 何をするSkillか（1行で説明できるか）
- user-invocable か context型か
- 必要なツール（最小限に絞る）
- どのSkillタイプに近いか（`${CLAUDE_SKILL_DIR}/reference.md` のタイプ分類を参照）

### 2. ディレクトリ作成

```bash
mkdir -p ~/.claude/skills/{skill-name}
```

### 3. SKILL.md 作成

以下のテンプレートに従って作成する。

## テンプレート

```markdown
---
name: {skill-name}
description: {何をするか}。「{トリガーワード1}」「{トリガーワード2}」等で起動。
user-invocable: true
allowed-tools:
  - {必要なツールのみ}
---

# /skill-name - 1行の説明

{Skillの目的を1-2文で記述}

## 実行手順

### 1. {最初のステップ}

{具体的な手順}

## Gotchas

- {Claudeが間違えやすいポイント、エッジケース、暗黙の前提}
```

### Gotchas セクションについて

Skillの中で最も価値が高いセクション。Claudeが手順通りにやっても失敗するパターンを事前に潰す。

- 初版では空でもいい。運用しながら失敗パターンを追記していく
- 「こう書くとClaudeがこう誤解する」のような具体的な記述が効果的
- 手順の理由（なぜそうするか）と補完関係にある。理由＝正しい道、Gotchas＝落とし穴

## 設計原則

### フロントマター必須フィールド

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | 必須 | kebab-case、ディレクトリ名と一致 |
| `description` | 必須 | トリガーワードを含める。Claudeのトリガー判定に使われる |
| `user-invocable` | 必須 | `/` コマンドで呼べるなら `true` |
| `allowed-tools` | 推奨 | 最小権限で指定。不要なツールは含めない |
| `argument-hint` | 任意 | 引数を取る場合のヒント |
| `disable-model-invocation` | 任意 | Subagent起動を禁止する場合 |

descriptionのコツ: Claudeは「アンダートリガー」しやすいため、トリガーワードは多めに列挙する。日本語と英語の両方を含めるとさらに安定する。

### 遅延ロードパターン

SKILL.mdは薄く保ち、詳細は外部ファイルに分離する。毎回contextに読み込まれるのはSKILL.mdだけなので、ここが肥大化するとcontext効率が下がる。

```
skills/my-skill/
  SKILL.md              ← インデックス（手順の骨格のみ）
  reference.md          ← 詳細ガイドライン（必要時のみ読み込み）
  templates/            ← テンプレートファイル群
  scripts/              ← 実行スクリプト群
```

SKILL.md内での参照方法:

```markdown
### 0. リファレンス読み込み（必要時のみ）

詳細な判断基準が必要な場合のみ参照する:
- `${CLAUDE_SKILL_DIR}/reference.md` — 詳細ガイドライン
```

目安: SKILL.mdが150行を超えたら分離を検討する。

### スクリプトはブラックボックス実行

scripts/ 配下のスクリプトは実行のみ行い、ソースコードをcontextに読み込まない。大きなスクリプトを読むとcontextウィンドウを汚染する。

```markdown
## スクリプト

以下のスクリプトは直接実行する。ソースコードを読む必要はない:
- `${CLAUDE_SKILL_DIR}/scripts/process.sh` — データ処理
```

### pane-manager参照パターン

Codexと連携するSkillでは、pane-manager.shのパスを変数に入れてから使う:

```bash
PANE_MGR=~/.claude/skills/codex-review/scripts/pane-manager.sh

$PANE_MGR ensure
$PANE_MGR send "メッセージ"
$PANE_MGR wait_response 180
$PANE_MGR capture 200
```

### Reader Testing（大規模出力向け）

自分が生成/分析した結果を検証するとき、著者バイアスで見落としが発生する。文脈ゼロのSubagentに読ませることで構造的に解決する:

```
Agent(subagent_type="general-purpose"):
  "以下の出力を読んで問題を探してください。
   作成の背景や意図は意図的に伝えません。出力だけから判断してください。
   - 内容が不明確な箇所
   - 矛盾している箇所
   - 暗黙の前提に依存している箇所"
```

適用場面: ドキュメント生成、PRレビュー、設計書作成など、出力の品質が重要なSkill。

### 「なぜそうするのか」を書く

Claudeが状況判断できるよう、手順だけでなく理由を書く。理由がわかれば、想定外の状況でも適切に判断できる。

悪い例:
```markdown
### 3. テスト実行
テストを実行する。
```

良い例:
```markdown
### 3. テスト実行
PR作成前にテストを通すことで、CIの待ち時間を削減しフィードバックを即座に得る。
```

## チェックリスト

作成完了時に確認:

- [ ] フロントマターに `name`, `description`, `user-invocable` がある
- [ ] descriptionにトリガーワードが含まれている
- [ ] allowed-toolsが最小権限になっている
- [ ] SKILL.mdが150行以内（超える場合は外部ファイルに分離）
- [ ] Gotchasセクションがある（初版は空でもOK、運用で追記）
- [ ] 手順に「なぜそうするのか」が含まれている
- [ ] `${CLAUDE_SKILL_DIR}` で自身のディレクトリを参照している
