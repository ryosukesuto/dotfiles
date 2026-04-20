#!/usr/bin/env python3
"""
finding-normalizer: 複数 reviewer の findings を dedupeして最終レポートを生成する。

Usage:
  python3 normalize.py --findings /tmp/codex-baseline.json --findings /tmp/opus-baseline.json
  python3 normalize.py --dir /tmp/findings/
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
ENTITY_KEY_RE = re.compile(r"^[^:]+:[^:]+(:[^:]+)?$")
LINE_RANGE_PROXIMITY = 20  # dedupe時に±N行を同一とみなす（reviewer間の行指定ずれを吸収）

SEVERITY_ORDER = {"must-fix": 0, "should-fix": 1, "watch": 2}

EVIDENCE_TYPE_WEIGHT = {
    "diff": 1.0,
    "code": 1.0,
    "static-analysis": 0.9,
    "log": 0.7,
    "config": 0.7,
}


def sha6(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()[:6]


def validate_finding(f: dict) -> list[str]:
    """見つかった品質違反を返す。空なら valid。"""
    errors = []

    # source_reviewer
    source_reviewer = f.get("source_reviewer", "")
    if source_reviewer not in VALID_REVIEWERS:
        errors.append(f"invalid source_reviewer: {source_reviewer}")

    # finding_id prefix matches source_reviewer
    finding_id = f.get("finding_id", "")
    if not finding_id.startswith(source_reviewer + "-"):
        errors.append(f"finding_id prefix mismatch: {finding_id} vs {source_reviewer}")

    # issue_type
    if f.get("issue_type") not in VALID_ISSUE_TYPES:
        errors.append(f"invalid issue_type: {f.get('issue_type')}")

    # entity_key format
    entity_key = f.get("entity_key", "")
    if not ENTITY_KEY_RE.match(entity_key):
        errors.append(f"invalid entity_key format: {entity_key}")

    # lines end >= start
    lines = f.get("lines", {})
    if isinstance(lines, dict):
        start = lines.get("start", 0)
        end = lines.get("end", 0)
        if end < start:
            errors.append(f"lines.end ({end}) < lines.start ({start})")

    # evidence
    evidence = f.get("evidence", {})
    if not isinstance(evidence, dict) or not evidence.get("evidence_type"):
        errors.append("evidence.evidence_type missing")
    if not isinstance(evidence, dict) or not evidence.get("excerpt", "").strip():
        errors.append("evidence.excerpt is empty")

    # evidence.location lines
    loc = evidence.get("location", {}) if isinstance(evidence, dict) else {}
    loc_lines = loc.get("lines", {}) if isinstance(loc, dict) else {}
    if isinstance(loc_lines, dict):
        ls = loc_lines.get("start", 0)
        le = loc_lines.get("end", 0)
        if le < ls:
            errors.append(f"evidence.location.lines.end ({le}) < start ({ls})")

    return errors


def normalize_lines_key(lines: dict) -> str:
    """dedupe 用の lines 正規化。±LINE_RANGE_PROXIMITY を丸める。"""
    start = lines.get("start", 0)
    end = lines.get("end", 0)
    s = (start // LINE_RANGE_PROXIMITY) * LINE_RANGE_PROXIMITY
    e = ((end + LINE_RANGE_PROXIMITY - 1) // LINE_RANGE_PROXIMITY) * LINE_RANGE_PROXIMITY
    return f"{s}-{e}"


def dedup_key(f: dict) -> str:
    """
    dedupe キー: repo + file + line-range + entity_key。
    issue_type はレビュアーによって分類がずれるため意図的に除外する。
    同一ファイル・同一行範囲・同一 entity（関数・シンボル）への指摘は同一とみなす。
    """
    repo = f.get("repo", "")
    file = f.get("file", "")
    lines = normalize_lines_key(f.get("lines", {}))
    entity_key = f.get("entity_key", "")
    return f"{repo}:{file}:{lines}:{entity_key}"


def evidence_specificity(f: dict) -> float:
    """
    evidence の具体性を 0.0-1.0 でスコア化する。
    - evidence_type: diff/code が最高、log/config は中、欠落は 0
    - excerpt 長さ: 200文字で満点
    - location の repo/file が finding 本体と一致するか
    """
    evidence = f.get("evidence", {})
    if not isinstance(evidence, dict):
        return 0.0

    etype = evidence.get("evidence_type", "")
    type_score = EVIDENCE_TYPE_WEIGHT.get(etype, 0.0)
    if type_score == 0.0:
        return 0.0

    excerpt = evidence.get("excerpt", "") or ""
    length_score = min(len(excerpt.strip()) / 200.0, 1.0)

    loc = evidence.get("location", {}) if isinstance(evidence, dict) else {}
    loc_match = 0.0
    if isinstance(loc, dict):
        if loc.get("repo") == f.get("repo") and loc.get("file") == f.get("file"):
            loc_match = 1.0

    # 重み: 種別 50%、長さ 30%、位置一致 20%
    return round(type_score * 0.5 + length_score * 0.3 + loc_match * 0.2, 3)


def arbitration_score(f: dict) -> float:
    """confidence × (0.6 + 0.4 × evidence_specificity)。"""
    conf = f.get("confidence", 0.0) or 0.0
    spec = evidence_specificity(f)
    return round(conf * (0.6 + 0.4 * spec), 4)


def _is_conflict(a: dict, b: dict) -> bool:
    """severity / issue_type / fix_hint の食い違いがあれば衝突とみなす。"""
    return (
        a.get("severity") != b.get("severity")
        or a.get("issue_type") != b.get("issue_type")
    )


def _merge_related_locations(a: dict, b: dict) -> list[dict]:
    locs = list(a.get("related_locations", [])) + list(b.get("related_locations", []))
    seen = set()
    out = []
    for loc in locs:
        k = f"{loc.get('repo')}:{loc.get('file')}:{loc.get('lines', {})}"
        if k not in seen:
            seen.add(k)
            out.append(loc)
    return out


def merge_findings(a: dict, b: dict) -> dict:
    """
    同一 dedupe key の findings をマージ。arbitration_score で勝者を決定。
    衝突時は敗者を rejected_alternatives に退避。同一指摘の場合は sources に追補。
    """
    score_a = arbitration_score(a)
    score_b = arbitration_score(b)
    if score_b > score_a:
        winner, loser = b, a
        winner_score, loser_score = score_b, score_a
    else:
        winner, loser = a, b
        winner_score, loser_score = score_a, score_b

    result = dict(winner)

    # sources: 両 reviewer を記録。既に sources があればマージ
    sources = list(result.get("sources", []))
    if not sources:
        sources = [winner.get("source_reviewer", "")]
    for src in [loser.get("source_reviewer", "")] + list(loser.get("sources", [])):
        if src and src not in sources:
            sources.append(src)
    result["sources"] = sources

    # related_locations を統合
    merged_locs = _merge_related_locations(winner, loser)
    if merged_locs:
        result["related_locations"] = merged_locs

    conflict = _is_conflict(winner, loser)

    arbitration = dict(result.get("arbitration", {}))
    arbitration["winner_score"] = winner_score

    rejected = list(arbitration.get("rejected_alternatives", []))
    # loser が元々 rejected を抱えていたら引き継ぐ
    for prior in loser.get("arbitration", {}).get("rejected_alternatives", []):
        rejected.append(prior)

    if conflict:
        rejected.append({
            "source_reviewer": loser.get("source_reviewer", ""),
            "severity": loser.get("severity"),
            "issue_type": loser.get("issue_type"),
            "confidence": loser.get("confidence"),
            "score": loser_score,
            "claim": loser.get("claim", ""),
            "reason": "severity_or_issue_type_differs",
        })
    else:
        # 同一指摘の corroboration: confidence を最大値+0.05 でブースト（上限 1.0）
        boosted = min(1.0, max(winner.get("confidence", 0.0), loser.get("confidence", 0.0)) + 0.05)
        result["confidence"] = round(boosted, 2)

    if rejected:
        arbitration["rejected_alternatives"] = rejected
    if arbitration:
        result["arbitration"] = arbitration

    return result


def apply_quality_filter(findings: list[dict]) -> tuple[list[dict], list[dict]]:
    """(kept, dropped) を返す。"""
    kept = []
    dropped = []
    for f in findings:
        errors = validate_finding(f)
        if errors:
            dropped.append({"finding": f, "reasons": errors})
            continue

        confidence = f.get("confidence", 1.0)
        evidence = f.get("evidence", {})
        excerpt = evidence.get("excerpt", "").strip() if isinstance(evidence, dict) else ""

        # low confidence + weak evidence → drop
        if confidence < 0.5 and not excerpt:
            dropped.append({"finding": f, "reasons": ["low confidence + empty evidence"]})
            continue

        kept.append(f)
    return kept, dropped


def adapt_via_script(path: str, reviewer_id: str | None) -> dict:
    """adapt-findings.py を呼び出して schema 変換する（インライン実装）。"""
    # adapt-findings.py のロジックを import するか、同ディレクトリにあれば直接呼ぶ
    import subprocess
    script = Path(__file__).parent / "adapt-findings.py"
    if not script.exists():
        return {"findings": [], "reviewer_id": reviewer_id or "unknown"}
    cmd = ["python3", str(script), "--input", path]
    if reviewer_id:
        cmd += ["--reviewer", reviewer_id]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"WARN: adapt-findings.py failed for {path}: {result.stderr}", file=sys.stderr)
        return {"findings": [], "reviewer_id": reviewer_id or "unknown"}
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description="Normalize and dedup findings from multiple reviewers")
    parser.add_argument("--findings", action="append", dest="finding_files", default=[], metavar="FILE")
    parser.add_argument("--dir", help="Directory containing reviewer output JSON files")
    parser.add_argument("--output", "-o", default="-")
    parser.add_argument(
        "--adapt",
        action="store_true",
        help="Run adapt-findings.py on each input file before normalizing (for LLM raw output)",
    )
    args = parser.parse_args()

    finding_files = list(args.finding_files)
    if args.dir:
        finding_files += sorted(Path(args.dir).glob("*.json"))

    if not finding_files:
        print("ERROR: No finding files specified.", file=sys.stderr)
        sys.exit(1)

    all_findings = []
    for fpath in finding_files:
        if args.adapt:
            data = adapt_via_script(str(fpath), None)
        else:
            with open(fpath) as f:
                data = json.load(f)

        # Accept wrapper format {reviewer_id, findings, meta} or plain list
        if isinstance(data, dict) and "findings" in data:
            raw_findings = data["findings"]
            # adapt が付けた quarantine ログも summary に含める
            quarantined_from_adapt = len(data.get("_quarantined", []))
            if quarantined_from_adapt:
                print(f"INFO: {quarantined_from_adapt} findings quarantined by adapter from {fpath}", file=sys.stderr)
        elif isinstance(data, list):
            raw_findings = data
        else:
            print(f"WARN: Unexpected format in {fpath}, skipping", file=sys.stderr)
            continue

        all_findings.extend(raw_findings)

    # Quality filter
    kept, dropped = apply_quality_filter(all_findings)

    # Dedup
    dedup_map: dict[str, dict] = {}
    for f in kept:
        key = dedup_key(f)
        if key in dedup_map:
            dedup_map[key] = merge_findings(dedup_map[key], f)
        else:
            dedup_map[key] = f

    normalized = list(dedup_map.values())

    # Sort: severity order, then confidence desc
    severity_order = {"must-fix": 0, "should-fix": 1, "watch": 2}
    normalized.sort(
        key=lambda f: (
            severity_order.get(f.get("severity", "watch"), 2),
            -f.get("confidence", 0),
        )
    )

    # Bucket by severity
    must_fix = [f for f in normalized if f.get("severity") == "must-fix"]
    should_fix = [f for f in normalized if f.get("severity") == "should-fix"]
    watch = [f for f in normalized if f.get("severity") == "watch"]

    report = {
        "schema_version": 1,
        "summary": {
            "total_input": len(all_findings),
            "dropped": len(dropped),
            "deduped_from": len(kept),
            "final": len(normalized),
            "must_fix": len(must_fix),
            "should_fix": len(should_fix),
            "watch": len(watch),
        },
        "must_fix": must_fix,
        "should_fix": should_fix,
        "watch": watch,
        "dropped": dropped,
    }

    output = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output == "-":
        print(output)
    else:
        Path(args.output).write_text(output)
        print(f"Normalized report written to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
