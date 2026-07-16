#!/usr/bin/env python3
"""normalize.pyのJSONから、著者向けのMarkdownレビューを生成する。

Usage:
  python3 report.py --report /tmp/report.json [--pr-ref "server#21746"] [--output review.md]
"""

import argparse
import json
import re
import sys
from pathlib import Path


INTERNAL_TERM_RE = re.compile(
    r"(?i)(?:must-fix|should-fix|\bwatch\b|\bP[0-3]\b|"
    r"codex-baseline|opus-baseline|review-server|security-review-(?:opus|codex)|"
    r"cross-repo|review-pr|proofread|triage|dedupe|finding-normalizer)"
)
REQUEST_RE = re.compile(
    r"(?:お願い|もらえると|もらえますか|いただけると|いただけますか|"
    r"してほしい|したいです|いかがでしょうか|できますか)"
)
JA_CHARS = r"\u3040-\u30ff\u3400-\u9fff"


def clean_public_text(value: object) -> str:
    """内部処理用の語をユーザー向け文章から除く。"""
    text = str(value or "").strip()
    text = re.sub(
        r"(?i)\[\s*(?:must-fix|should-fix|watch|P[0-3])\s*\]\s*",
        "",
        text,
    )
    text = INTERNAL_TERM_RE.sub("", text)
    text = re.sub(r"^(?:の確認)?(?:では|で)[、,]?[ \t]*", "", text)
    text = re.sub(r"\*\*([^*\n]+)\*\*", r"\1", text)
    text = re.sub(rf"([{JA_CHARS}])[ \t]+(?=[A-Za-z0-9`])", r"\1", text)
    text = re.sub(rf"(?<=[A-Za-z0-9`)\]])[ \t]+([{JA_CHARS}])", r"\1", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"[ \t]+([、。！？!?:：])", r"\1", text)
    return text.strip(" -:：\n")


def build_fallback_draft(claim: str, why: str, fix: str) -> str:
    """旧形式や不適切な草案向けに、構造化フィールドから草案を作る。"""
    def first_sentence(value: str) -> str:
        text = value.strip()
        end_positions = [text.find(mark) for mark in "。！？" if text.find(mark) >= 0]
        if end_positions:
            text = text[: min(end_positions) + 1]
        return text

    claim_text = first_sentence(claim)
    if claim_text and claim_text[-1:] not in "。！？":
        claim_text += "。"
    parts = [claim_text] if claim_text else []

    why_text = first_sentence(why)
    if why_text and why_text.rstrip("。！？") != claim_text.rstrip("。！？"):
        if why_text[-1:] not in "。！？":
            why_text += "。"
        parts.append(why_text)

    if fix:
        direction = first_sentence(fix).rstrip("。！!？?🙏")
        if "ください" in direction:
            direction = "指摘した条件を扱えるように実装を見直す"
        parts.append(f"{direction}形で進めてもらえると助かります🙏")
    return "".join(parts)


def clean_review_draft(raw: object, claim: str, why: str, fix: str) -> str:
    """レビュー草案を公開用に整え、内部語があれば安全な草案へ戻す。"""
    draft = str(raw or "").strip()
    if not draft or INTERNAL_TERM_RE.search(draft):
        draft = build_fallback_draft(claim, why, fix)

    draft = clean_public_text(draft)
    if "ください" in draft:
        draft = build_fallback_draft(claim, why, fix)

    draft = re.sub(r"\s+🙏", "🙏", draft).replace("🙏", "").rstrip()
    if REQUEST_RE.search(draft):
        draft = draft.rstrip("。.!！ ") + "🙏"
    return draft


def soften_explanation(text: str) -> str:
    if "ください" in text:
        return "指摘した条件を扱えるように実装を見直す。"
    return text


def format_quote(text: str) -> str:
    return "\n".join(">" if not line else f"> {line}" for line in text.splitlines())


def format_finding(finding: dict, index: int) -> str:
    file_path = finding.get("file", "")
    line_range = finding.get("lines", {})
    start = line_range.get("start", "?")
    end = line_range.get("end", "?")
    line_ref = f"{file_path}:{start}" if start == end else f"{file_path}:{start}-{end}"

    claim = soften_explanation(clean_public_text(finding.get("claim"))) or "確認したい点"
    why = soften_explanation(clean_public_text(finding.get("why_it_matters"))) or claim
    fix = soften_explanation(clean_public_text(finding.get("fix_hint")))
    draft = clean_review_draft(finding.get("review_draft"), claim, why, fix)

    evidence = finding.get("evidence", {})
    excerpt = str(evidence.get("excerpt", "") or "").strip()
    if excerpt == "(no excerpt)":
        excerpt = ""
    if len(excerpt) > 500:
        excerpt = excerpt[:500].rstrip() + "..."

    evidence_block = (
        f"```\n{excerpt}\n```" if excerpt else "根拠となる抜粋はありません。"
    )
    fix_block = fix or "追加の修正案はありません。"
    draft_block = format_quote(draft or build_fallback_draft(claim, why, fix))

    return f"""### {index}. {claim}

#### 対象箇所

`{line_ref}`

#### 詳細

{why}

#### 根拠

{evidence_block}

#### 修正の方向

{fix_block}

#### レビュー草案

{draft_block}

"""


def build_report(data: dict, pr_ref: str) -> str:
    # JSON上の区分は並び替えにだけ使い、区分名そのものは表示しない。
    before_merge = data.get("must_fix", [])
    additional = data.get("should_fix", [])
    notes = data.get("watch", [])
    total = len(before_merge) + len(additional) + len(notes)

    if before_merge:
        verdict = f"マージ前に確認したい点が{len(before_merge)}件あります。"
    elif additional:
        verdict = f"マージを止める問題は見つかりませんでした。あわせて確認したい点が{len(additional)}件あります。"
    elif notes:
        verdict = f"マージを止める問題は見つかりませんでした。補足が{len(notes)}件あります。"
    else:
        verdict = "マージを止める問題は見つかりませんでした。"

    lines = ["# コードレビュー結果\n\n"]
    if pr_ref:
        lines.append(f"PR `{pr_ref}`\n\n")
    lines.append(f"{verdict}\n\n確認した指摘は{total}件です。\n")

    sections = (
        ("マージ前に確認したい点", before_merge),
        ("あわせて確認したい点", additional),
        ("補足", notes),
    )
    for title, findings in sections:
        if not findings:
            continue
        lines.append(f"\n## {title}（{len(findings)}件）\n\n")
        for index, finding in enumerate(findings, 1):
            lines.append(format_finding(finding, index))

    return "".join(lines).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate an author-facing Markdown review from normalize.py output"
    )
    parser.add_argument("--report", "-r", required=True)
    parser.add_argument("--pr-ref", default="")
    parser.add_argument("--output", "-o", default="-")
    args = parser.parse_args()

    with open(args.report, encoding="utf-8") as report_file:
        data = json.load(report_file)

    markdown = build_report(data, args.pr_ref)

    if args.output == "-":
        print(markdown, end="")
    else:
        Path(args.output).write_text(markdown, encoding="utf-8")
        print(f"Report written to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
