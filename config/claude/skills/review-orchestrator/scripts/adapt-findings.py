#!/usr/bin/env python3
"""
finding-adapter: LLM reviewer の出力を finding.schema.json 準拠に変換する。
フォーマットが異なっても normalize.py が drop しないよう前処理する。

Usage:
  python3 adapt-findings.py --input /tmp/raw-findings.json --reviewer codex-baseline
  python3 adapt-findings.py --dir /tmp/raw/  # ディレクトリ内の全JSONを処理
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

VALID_REVIEWERS = {
    "codex-baseline", "opus-baseline", "review-server",
    "security-review-opus", "security-review-codex", "cross-repo",
}
VALID_ISSUE_TYPES = {
    "concurrency", "security", "contract", "perf", "error-handling",
    "naming", "test-coverage", "config", "data-migration", "iam",
    "observability", "other",
}
VALID_SEVERITIES = {"must-fix", "should-fix", "watch"}
VALID_EVIDENCE_TYPES = {"diff", "code", "log", "config", "static-analysis"}

# LLMが使いがちな別名 → issue_type のマッピング
ISSUE_TYPE_ALIASES = {
    "correctness": "error-handling",
    "reliability": "error-handling",
    "atomicity": "concurrency",
    "scalability": "perf",
    "performance": "perf",
    "design-intent": "other",
    "api-contract": "contract",
    "design": "contract",
    "api": "contract",
    "security": "security",
    "auth": "security",
    "iam": "iam",
    "observability": "observability",
    "monitoring": "observability",
    "naming": "naming",
    "style": "naming",
    "testing": "test-coverage",
    "test": "test-coverage",
    "migration": "data-migration",
    "db": "data-migration",
    "database": "data-migration",
    "config": "config",
    "configuration": "config",
}

# severity の別名
SEVERITY_ALIASES = {
    "critical": "must-fix",
    "high": "must-fix",
    "medium": "should-fix",
    "low": "watch",
    "info": "watch",
    "p0": "must-fix",
    "p1": "should-fix",
    "p2": "watch",
    "p3": "watch",
}


def sha6(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()[:6]


def normalize_issue_type(raw: str) -> str:
    if not raw:
        return "other"
    lower = raw.lower().strip().replace("_", "-")
    if lower in VALID_ISSUE_TYPES:
        return lower
    return ISSUE_TYPE_ALIASES.get(lower, "other")


def normalize_severity(raw: str) -> str:
    if not raw:
        return "watch"
    lower = raw.lower().strip().replace("_", "-")
    if lower in VALID_SEVERITIES:
        return lower
    return SEVERITY_ALIASES.get(lower, "watch")


def normalize_lines(raw) -> dict:
    """様々な lines 形式を {start, end} に正規化する。"""
    if isinstance(raw, dict):
        start = int(raw.get("start", raw.get("line_range_start", raw.get("from", 1))))
        end = int(raw.get("end", raw.get("line_range_end", raw.get("to", start))))
        if end < start:
            end = start
        return {"start": max(1, start), "end": max(1, end)}
    if isinstance(raw, str):
        # "123-145" or "123"
        m = re.match(r"(\d+)(?:[:\-](\d+))?", raw)
        if m:
            start = int(m.group(1))
            end = int(m.group(2)) if m.group(2) else start
            return {"start": start, "end": max(start, end)}
    return {"start": 1, "end": 1}


def build_entity_key(repo: str, file: str, symbol: str = "") -> str:
    if not repo:
        repo = "unknown"
    if not file:
        file = "unknown"
    if symbol:
        return f"{repo}:{file}:{symbol}"
    return f"{repo}:{file}"


def build_evidence(raw_finding: dict, repo: str, file: str, lines: dict) -> dict:
    """evidence を finding.schema.json の形式に変換する。"""
    # raw が既に正しい形式
    evidence = raw_finding.get("evidence", {})
    if isinstance(evidence, dict) and evidence.get("evidence_type") and evidence.get("excerpt"):
        et = evidence["evidence_type"]
        if et not in VALID_EVIDENCE_TYPES:
            et = "code"
        loc = evidence.get("location", {})
        if not isinstance(loc, dict) or not loc:
            loc = {"repo": repo, "file": file, "lines": lines}
        else:
            loc_lines = loc.get("lines", lines)
            loc = {
                "repo": loc.get("repo", repo),
                "file": loc.get("file", file),
                "lines": normalize_lines(loc_lines),
            }
        return {
            "evidence_type": et,
            "excerpt": evidence["excerpt"].strip(),
            "location": loc,
        }

    # LLM が evidence を別フィールドに書いた場合
    # description/context/suggestion などから excerpt を取る
    excerpt = (
        raw_finding.get("context", "")
        or raw_finding.get("description", "")
        or raw_finding.get("suggestion", "")
        or raw_finding.get("claim", "")
        or raw_finding.get("title", "")
    )
    if isinstance(evidence, str):
        excerpt = evidence

    # evidence フィールド内の file/excerpt キーを探す
    if isinstance(evidence, dict):
        excerpt = evidence.get("excerpt", "") or excerpt
        ev_file = evidence.get("file", file)
        ev_lines = evidence.get("lines", lines)
        return {
            "evidence_type": "code",
            "excerpt": str(excerpt).strip()[:500] if excerpt else "(no excerpt)",
            "location": {"repo": repo, "file": ev_file, "lines": normalize_lines(ev_lines)},
        }

    return {
        "evidence_type": "code",
        "excerpt": str(excerpt).strip()[:500] if excerpt else "(no excerpt)",
        "location": {"repo": repo, "file": file, "lines": lines},
    }


def adapt_finding(raw: dict, reviewer_id: str) -> dict | None:
    """生の finding を schema 準拠に変換する。変換不可能なら None を返す。"""
    if not isinstance(raw, dict):
        return None

    repo = raw.get("repo", "")
    file_path = (
        raw.get("file", "")
        or (raw.get("evidence", {}) or {}).get("file", "")
    )
    if not repo and file_path:
        # repo が未指定の場合、reviewer_id のコンテキストから推定できないため unknown
        repo = "unknown"

    lines_raw = (
        raw.get("lines")
        or raw.get("line_range")
        or {"start": raw.get("line_range_start", 1), "end": raw.get("line_range_end", 1)}
    )
    lines = normalize_lines(lines_raw)

    # claim
    claim = (
        raw.get("claim")
        or raw.get("title")
        or raw.get("summary")
        or raw.get("description", "")[:120]
    )
    if not claim:
        return None

    # why_it_matters
    why = (
        raw.get("why_it_matters")
        or raw.get("description")
        or raw.get("impact")
        or raw.get("rationale")
        or claim
    )

    # issue_type
    issue_type = normalize_issue_type(
        raw.get("issue_type") or raw.get("category") or raw.get("type", "")
    )

    # severity
    severity = normalize_severity(
        raw.get("severity") or raw.get("priority", "")
    )

    # confidence
    confidence = float(raw.get("confidence", 0.7))
    confidence = round(max(0.0, min(1.0, confidence)), 2)

    # entity_key
    symbol = (
        raw.get("symbol")
        or raw.get("function")
        or raw.get("method")
        or ""
    )
    entity_key = (
        raw.get("entity_key")
        or build_entity_key(repo, file_path, symbol)
    )
    # entity_key の正規化
    if not re.match(r"^[^:]+:[^:]+(:[^:]+)?$", entity_key):
        entity_key = build_entity_key(repo, file_path)

    # source_reviewer
    source_reviewer = raw.get("source_reviewer") or reviewer_id
    if source_reviewer not in VALID_REVIEWERS:
        source_reviewer = reviewer_id

    # evidence
    evidence = build_evidence(raw, repo, file_path, lines)

    # finding_id
    finding_id = raw.get("finding_id", "")
    if not finding_id or not finding_id.startswith(source_reviewer + "-"):
        hash_input = f"{repo}{file_path}{lines['start']}{lines['end']}{issue_type}{entity_key}"
        finding_id = f"{source_reviewer}-{sha6(hash_input)}"

    return {
        "finding_id": finding_id,
        "source_reviewer": source_reviewer,
        "severity": severity,
        "confidence": confidence,
        "issue_type": issue_type,
        "entity_key": entity_key,
        "repo": repo,
        "file": file_path,
        "lines": lines,
        "claim": str(claim).strip()[:200],
        "evidence": evidence,
        "why_it_matters": str(why).strip()[:500] if why else str(claim).strip()[:200],
        "fix_hint": raw.get("fix_hint") or raw.get("suggestion") or raw.get("remediation"),
        "related_locations": raw.get("related_locations", []),
    }


def process_file(path: str, reviewer_id: str | None) -> dict:
    with open(path) as f:
        data = json.load(f)

    if isinstance(data, dict) and "findings" in data:
        rid = reviewer_id or data.get("reviewer_id", "opus-baseline")
        raw_findings = data["findings"]
        meta = data.get("meta", {})
    elif isinstance(data, list):
        rid = reviewer_id or "opus-baseline"
        raw_findings = data
        meta = {}
    else:
        return {"reviewer_id": reviewer_id or "unknown", "findings": [], "meta": {}}

    adapted = []
    quarantined = []
    for raw in raw_findings:
        result = adapt_finding(raw, rid)
        if result is None:
            quarantined.append({"raw": raw, "reason": "conversion failed"})
        elif not result.get("file") or not result.get("repo"):
            quarantined.append({"raw": raw, "reason": "missing repo or file"})
        else:
            adapted.append(result)

    if quarantined:
        print(f"WARN: {len(quarantined)} findings quarantined from {path}", file=sys.stderr)

    return {
        "reviewer_id": rid,
        "findings": adapted,
        "meta": meta,
        "_quarantined": quarantined,
    }


def main():
    parser = argparse.ArgumentParser(description="Adapt LLM reviewer output to finding.schema.json")
    parser.add_argument("--input", "-i", help="Input JSON file")
    parser.add_argument("--dir", help="Directory of raw JSON files")
    parser.add_argument("--reviewer", help="Override reviewer_id (for files missing it)")
    parser.add_argument("--output", "-o", default="-", help="Output file (- for stdout)")
    parser.add_argument("--in-place", action="store_true", help="Overwrite input file")
    args = parser.parse_args()

    inputs = []
    if args.input:
        inputs.append(args.input)
    if args.dir:
        inputs += sorted(Path(args.dir).glob("*.json"))

    if not inputs:
        print("ERROR: Specify --input or --dir", file=sys.stderr)
        sys.exit(1)

    if len(inputs) == 1:
        result = process_file(str(inputs[0]), args.reviewer)
        output = json.dumps(result, ensure_ascii=False, indent=2)
        if args.in_place and args.input:
            Path(args.input).write_text(output)
            print(f"Adapted in-place: {args.input}", file=sys.stderr)
        elif args.output == "-":
            print(output)
        else:
            Path(args.output).write_text(output)
            print(f"Adapted findings written to: {args.output}", file=sys.stderr)
    else:
        results = []
        for p in inputs:
            results.append(process_file(str(p), args.reviewer))
        output = json.dumps(results, ensure_ascii=False, indent=2)
        if args.output == "-":
            print(output)
        else:
            Path(args.output).write_text(output)
            print(f"Adapted findings written to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
