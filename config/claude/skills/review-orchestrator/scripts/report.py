#!/usr/bin/env python3
"""
report: normalize.py の出力（JSON）から markdown レポートを自動生成する。

Usage:
  python3 report.py --report /tmp/report.json [--pr-ref "server#21746"] [--output review.md]
"""

import argparse
import json
import sys
from pathlib import Path


def severity_label(sev: str) -> str:
    return {"must-fix": "🔴 must-fix", "should-fix": "🟡 should-fix", "watch": "⚪ watch"}.get(sev, sev)


def confidence_bar(conf: float) -> str:
    bars = int(conf * 5)
    return "█" * bars + "░" * (5 - bars)


def format_finding(f: dict, idx: int) -> str:
    sev = f.get("severity", "")
    conf = f.get("confidence", 0)
    reviewer = f.get("source_reviewer", "")
    file_path = f.get("file", "")
    lines = f.get("lines", {})
    start = lines.get("start", "?")
    end = lines.get("end", "?")
    line_ref = f"{file_path}:{start}" if start == end else f"{file_path}:{start}-{end}"
    claim = f.get("claim", "")
    why = f.get("why_it_matters", "")
    fix = f.get("fix_hint", "")
    issue_type = f.get("issue_type", "")

    evidence = f.get("evidence", {})
    excerpt = evidence.get("excerpt", "")

    lines_block = ""
    if excerpt and excerpt.strip() and excerpt != "(no excerpt)":
        # 長すぎる抜粋は折りたたむ
        if len(excerpt) > 300:
            excerpt = excerpt[:300] + "..."
        lines_block = f"\n```\n{excerpt}\n```\n"

    fix_block = f"\n**修正方法**: {fix}" if fix else ""

    return f"""**{idx}. {claim}**
`{line_ref}` | {reviewer} | {issue_type} | confidence {confidence_bar(conf)} {conf:.0%}
{lines_block}
{why}{fix_block}

"""


def build_report(data: dict, pr_ref: str) -> str:
    summary = data.get("summary", {})
    must_fix = data.get("must_fix", [])
    should_fix = data.get("should_fix", [])
    watch = data.get("watch", [])
    dropped = data.get("dropped", [])

    total_input = summary.get("total_input", 0)
    final = summary.get("final", 0)
    deduped = total_input - final - len(dropped)

    pr_line = f"**PR**: {pr_ref}\n\n" if pr_ref else ""

    # サマリ行
    must_n = len(must_fix)
    should_n = len(should_fix)
    watch_n = len(watch)
    dropped_n = len(dropped)

    verdict = ""
    if must_n > 0:
        verdict = f"🔴 **マージ前対応必須** — must-fix {must_n}件を先に解決してください"
    elif should_n > 0:
        verdict = f"🟡 **対応推奨** — must-fix なし、should-fix {should_n}件を確認してください"
    else:
        verdict = "✅ **マージ可能** — 重要な指摘なし"

    lines = []
    lines.append(f"# コードレビュー結果\n")
    lines.append(f"{pr_line}")
    lines.append(f"{verdict}\n")
    lines.append(
        f"入力 {total_input}件 → dedupe {deduped}件 → drop {dropped_n}件 → **最終 {final}件**"
        f"（must-fix: {must_n} / should-fix: {should_n} / watch: {watch_n}）\n"
    )

    if must_fix:
        lines.append(f"\n## 🔴 must-fix（{must_n}件）\n")
        for i, f in enumerate(must_fix, 1):
            lines.append(format_finding(f, i))

    if should_fix:
        lines.append(f"\n## 🟡 should-fix（{should_n}件）\n")
        for i, f in enumerate(should_fix, 1):
            lines.append(format_finding(f, i))

    if watch:
        lines.append(f"\n## ⚪ watch（{watch_n}件）\n")
        for i, f in enumerate(watch, 1):
            lines.append(format_finding(f, i))

    if dropped:
        lines.append(f"\n---\n\n<details><summary>drop された指摘 {dropped_n}件</summary>\n\n")
        for d in dropped:
            finding = d.get("finding", {})
            reasons = d.get("reasons", [])
            lines.append(f"- `{finding.get('file', '?')}` — {', '.join(reasons)}\n")
        lines.append("</details>\n")

    return "".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate markdown review report from normalize.py output")
    parser.add_argument("--report", "-r", required=True)
    parser.add_argument("--pr-ref", default="")
    parser.add_argument("--output", "-o", default="-")
    args = parser.parse_args()

    with open(args.report) as f:
        data = json.load(f)

    md = build_report(data, args.pr_ref)

    if args.output == "-":
        print(md)
    else:
        Path(args.output).write_text(md)
        print(f"Report written to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
