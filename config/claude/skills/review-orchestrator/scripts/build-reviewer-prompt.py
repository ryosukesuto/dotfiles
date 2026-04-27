#!/usr/bin/env python3
"""
build-reviewer-prompt: bundle.json + git diff から reviewer 用プロンプトを自動生成する。

Usage:
  python3 build-reviewer-prompt.py \
    --bundle /tmp/bundle.json \
    --triage /tmp/triage.json \
    --reviewer codex-baseline \
    --repo-root server:/path/to/server \
    [--output /tmp/prompt-codex.txt]
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).parent.parent

OBSERVATION_POINTS = {
    "codex-baseline": "実装詳細、エッジケース（境界値、空入力、ゼロ値、同時実行、権限不足）、シェル/Goスクリプトのロバスト性、nil参照、エラーハンドリング漏れ",
    "opus-baseline": "設計意図、影響範囲、APIコントラクト整合性、既存コードとの一貫性、仕様の曖昧さ、将来の保守性",
    "review-server": "クリーンアーキテクチャ準拠、レイヤー責務、DBトランザクション境界、サーバー側コーディング規約",
    "security-review-opus": "認証/認可、入力検証、シークレット露出、権限昇格、監査ログ欠如、OWASP Top10",
    "security-review-codex": "セキュリティ実装の詳細（SQLi/XSS/SSRF/パス traversal）、Semgrep/gosec 相当の静的解析観点",
    "cross-repo": "インターフェース変更の consumer 側影響（pinpoint クエリのみ回答）",
}

# specialist reviewer ごとに追加で読み込ませる既存 skill / ガイダンス。
# subagent が指摘を返す前に該当 skill を読むことで、サービス固有の規約・観点を反映させる。
SPECIALIST_SKILL_HINTS = {
    "review-server": (
        "このレビューは WinTicket/server リポジトリ専用の specialist 観点で行う。"
        "subagent は最初に `~/.claude/skills/review-server/SKILL.md` を Read し、"
        "クリーンアーキテクチャ / コーディング規約 / クロスリポジトリ整合性 / ローカル知識を把握してから findings を抽出する。"
        "review-server skill 内部のチェックリストと本プロンプトの出力フォーマットの両方に従うこと。"
    ),
    "security-review-opus": (
        "このレビューはセキュリティ観点（Opus系）の specialist。"
        "subagent は `~/.claude/skills/security-review/SKILL.md` を Read し、OWASP Top 10 / 認証・認可 / シークレット露出を中心に評価する。"
        "LLM 単独の推測でなく、diff や relevant_snippets の具体箇所に必ず紐付ける（false positive 抑制のため）。"
    ),
    "security-review-codex": (
        "このレビューはセキュリティ観点（Codex系）の specialist で、security-review-opus と cross-validation する役割。"
        "subagent は `~/.claude/skills/security-review/SKILL.md` を Read したうえで、"
        "SQLi / XSS / SSRF / path traversal / コマンド injection / 権限チェック漏れ など実装詳細寄りの脆弱性に焦点を当てる。"
        "Semgrep/gosec 相当の静的解析観点から、パターン一致を evidence として抜粋する。"
    ),
    "cross-repo": (
        "このレビューは cross-repo specialist。triage.must_check_interfaces の各エントリについて、"
        "候補リポで consumer 側の参照箇所を調査する。`~/.claude/skills/cross-repo/SKILL.md` を参照。"
        "pinpoint（ファイル・シンボル指定）→ Read、scoped（ディレクトリ+パターン）→ Grep+Read、survey（概念検索）は原則禁止で最後の手段。"
        "entity_key は consumer 側の位置ではなく triage.must_check_interfaces.source_repo:source_path:source_symbol を使う。"
        "consumer 側の具体位置は related_locations[] に入れる。"
    ),
}

FIELD_TABLE = """
## フィールド仕様（必読・全フィールド必須）

| フィールド | 型 | 制約 |
|-----------|-----|------|
| finding_id | string | `{reviewer_id}-` + 6文字の識別子 |
| source_reviewer | string | reviewer_id と同じ値 |
| severity | string | `must-fix` / `should-fix` / `watch` のみ |
| confidence | number | 0.00〜1.00 の小数（例: 0.85） |
| issue_type | string | `concurrency` / `security` / `contract` / `perf` / `error-handling` / `naming` / `test-coverage` / `config` / `data-migration` / `iam` / `observability` / `other` のみ |
| entity_key | string | `{repo}:{path}:{symbol}` 形式（symbol不明時は `{repo}:{path}`） |
| repo | string | リポジトリ名 |
| file | string | リポジトリルートからの相対パス |
| lines | object | `{"start": N, "end": N}`（根拠コードの実際の行範囲に限定。関数全体や50行超の広い範囲は禁止） |
| claim | string | 問題の1行主張（200文字以内） |
| evidence.evidence_type | string | `diff` / `code` / `config` / `log` / `static-analysis` のみ |
| evidence.excerpt | string | 実際のコード抜粋（空禁止。20文字以上） |
| evidence.location | object | `{repo, file, lines}` |
| why_it_matters | string | claim の言い換え禁止。影響・リスクを記述 |
| fix_hint | string | must-fix/should-fix では必須。watch では任意 |

禁止フィールド名: `category` `title` `description` `suggestion` `impact` `recommendation`
"""

OUTPUT_FORMAT = """
## 出力フォーマット（厳守）

JSONのみ出力。前置き・説明文・まとめは一切禁止。

```json
{
  "reviewer_id": "REVIEWER_ID",
  "findings": [
    {
      "finding_id": "REVIEWER_ID-a1b2c3",
      "source_reviewer": "REVIEWER_ID",
      "severity": "must-fix",
      "confidence": 0.85,
      "issue_type": "error-handling",
      "entity_key": "REPO:path/to/file.go:FunctionName",
      "repo": "REPO",
      "file": "path/to/file.go",
      "lines": {"start": 42, "end": 48},
      "related_locations": [],
      "claim": "問題の1行主張",
      "evidence": {
        "evidence_type": "code",
        "excerpt": "実際のコード抜粋（20文字以上）",
        "location": {"repo": "REPO", "file": "path/to/file.go", "lines": {"start": 42, "end": 45}}
      },
      "why_it_matters": "claimの言い換えでない影響・リスクの説明",
      "fix_hint": "具体的な修正方法"
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

上限: must-fix=5件、should-fix=10件、watch=15件
"""


def get_diff_for_file(repo_root: str, base_sha: str, head_sha: str, path: str) -> str:
    """git diff で特定ファイルの diff を取得する。"""
    try:
        result = subprocess.run(
            ["git", "diff", base_sha, head_sha, "--", path],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        return result.stdout
    except Exception:
        return ""


def build_diff_context(bundle: dict, triage: dict, repo_roots: dict, reviewer_id: str) -> str:
    """bundle の review_slices から reviewer に渡す diff コンテキストを組み立てる。"""
    slices = bundle.get("review_slices", {}).get(reviewer_id, [])
    if not slices:
        slices = bundle.get("review_slices", {}).get("opus-baseline", [])

    base_sha = triage.get("base_sha", "")
    head_sha = triage.get("head_sha", "")

    sections = []
    for s in slices:
        repo = s.get("repo", "")
        path = s.get("path", "")
        reason = s.get("reason", "")
        root = repo_roots.get(repo, "")

        diff = ""
        if root and base_sha and head_sha:
            diff = get_diff_for_file(root, base_sha, head_sha, path)

        # snippets from bundle
        snippets = [
            sn for sn in bundle.get("relevant_snippets", [])
            if sn.get("repo") == repo and sn.get("path") == path
        ]

        section = f"### {repo}/{path}（{reason}）\n"
        if diff:
            section += f"```diff\n{diff[:3000]}\n```\n"
        elif snippets:
            for sn in snippets[:2]:
                lines = sn.get("lines", {})
                section += f"```go\n// L{lines.get('start','')}〜L{lines.get('end','')}\n{sn.get('content', '')[:1500]}\n```\n"
        else:
            section += "（diff 取得不可）\n"

        sections.append(section)

    return "\n".join(sections) if sections else "（diff なし）"


def build_prompt(bundle: dict, triage: dict, repo_roots: dict, reviewer_id: str) -> str:
    pr_ref = triage.get("pr_ref", "")
    pr_meta = bundle.get("pr_metadata", {}) or triage.get("pr_metadata", {}) or {}
    pr_title = pr_meta.get("title", "")
    pr_body = pr_meta.get("body", "")
    size = triage.get("size", "")
    risk_tags = triage.get("risk_tags", [])
    interface_changes = bundle.get("interface_changes", {})

    # 変更ファイル一覧
    manifest = bundle.get("changed_file_manifest", [])
    file_list = "\n".join(
        f"  - {f['repo']}/{f['path']} ({f['status']}, +{f['additions']}/-{f['deletions']})"
        for f in manifest
    )

    # インターフェース変更サマリ
    iface_lines = []
    for sym in interface_changes.get("symbols", []):
        iface_lines.append(f"  - symbol: {sym.get('repo')}/{sym.get('path')} {sym.get('name')} ({sym.get('kind')})")
    for proto in interface_changes.get("protos", []):
        iface_lines.append(f"  - proto: {proto.get('repo')}/{proto.get('path')}")
    iface_summary = "\n".join(iface_lines) if iface_lines else "  なし"

    diff_context = build_diff_context(bundle, triage, repo_roots, reviewer_id)
    obs_points = OBSERVATION_POINTS.get(reviewer_id, "全般的なコードレビュー")
    specialist_hint = SPECIALIST_SKILL_HINTS.get(reviewer_id, "")
    specialist_section = ""
    if specialist_hint:
        specialist_section = f"\n## specialist ガイダンス（事前読込み必須）\n{specialist_hint}\n"

    # hack ツール判定
    is_hack = any("hack/" in f.get("path", "") for f in manifest)
    hack_note = ""
    if is_hack:
        hack_note = """
## hack ツールへの注意
このPRは本番コードではなく社内 hack ツール（調査スクリプト等）への変更を含みます。
- 差し押さえ・法的手続き用途では証跡の完全性が最重要
- データ漏れ・欠落は must-fix、本番コードより厳格に判断する
- 本番 API を呼ぶため無制限ループ・大量 RPC は本番環境への影響として扱う
"""

    pr_body_section = ""
    if pr_body:
        body_truncated = pr_body[:3000] + ("..." if len(pr_body) > 3000 else "")
        pr_body_section = f"\n## PR Description（著者の意図・前提条件・マージ前提として必読）\n{body_truncated}\n"

    prompt = f"""あなたは reviewer_id="{reviewer_id}" として動作します。

## PR概要
- PR: {pr_ref}
- タイトル: {pr_title}
- サイズ: {size}
- リスクタグ: {', '.join(risk_tags) if risk_tags else 'なし'}
{pr_body_section}
## 変更ファイル
{file_list}

## インターフェース変更
{iface_summary}
{hack_note}
## タスク

1. 以下の diff を読む
2. 担当観点で findings を列挙する
3. 出力フォーマットに厳密に従って JSON のみ出力する

## 担当観点（{reviewer_id}）
{obs_points}
{specialist_section}
## diff
{diff_context}

{FIELD_TABLE}

{OUTPUT_FORMAT.replace('REVIEWER_ID', reviewer_id).replace('REPO', list(repo_roots.keys())[0] if repo_roots else 'server')}
"""
    return prompt


def main():
    parser = argparse.ArgumentParser(description="Generate reviewer prompt from bundle + triage")
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--triage", required=True)
    parser.add_argument("--reviewer", required=True)
    parser.add_argument(
        "--repo-root",
        action="append",
        dest="repo_roots",
        metavar="NAME:PATH",
        default=[],
    )
    parser.add_argument("--output", "-o", default="-")
    args = parser.parse_args()

    with open(args.bundle) as f:
        bundle = json.load(f)
    with open(args.triage) as f:
        triage = json.load(f)

    repo_roots = {}
    for r in args.repo_roots:
        if ":" in r:
            name, path = r.split(":", 1)
            repo_roots[name] = path
    if not repo_roots:
        for k, v in triage.get("repo_roots", {}).items():
            repo_roots[k] = v

    prompt = build_prompt(bundle, triage, repo_roots, args.reviewer)

    if args.output == "-":
        print(prompt)
    else:
        Path(args.output).write_text(prompt)
        print(f"Prompt written to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
