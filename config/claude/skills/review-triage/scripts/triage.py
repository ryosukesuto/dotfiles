#!/usr/bin/env python3
"""
review-triage: PR/git diff から triage.schema.json 準拠の JSON を出力する。
機械判定優先、LLMに丸投げしない。

Usage:
  python3 triage.py --pr-ref "github.com/org/repo#123" \
                    --base-sha abc1234 --head-sha def5678 \
                    --repo server:/path/to/server \
                    --repo server-config:/path/to/server-config \
                    --diff-stat /tmp/diffstat.txt \
                    --diff-files /tmp/changed_files.txt

  python3 triage.py --local-diff \
                    --base-sha abc1234 --head-sha def5678 \
                    --repo server:/path/to/server \
                    ...
"""

import argparse
import fnmatch
import json
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

SKILL_DIR = Path(__file__).parent.parent
ORCHESTRATOR_DIR = SKILL_DIR.parent / "review-orchestrator"
CONFIG_PATH = ORCHESTRATOR_DIR / "triage-config.yaml"


def load_config() -> dict:
    with open(CONFIG_PATH) as f:
        return yaml.safe_load(f)


def match_pattern(path: str, pattern: str) -> bool:
    """fnmatch glob matching, also matches basename."""
    if fnmatch.fnmatch(path, pattern):
        return True
    # Match against basename
    if fnmatch.fnmatch(os.path.basename(path), pattern):
        return True
    # Match against any path component for simple directory patterns
    parts = path.replace("\\", "/").split("/")
    for i in range(len(parts)):
        sub = "/".join(parts[i:])
        if fnmatch.fnmatch(sub, pattern):
            return True
    return False


def classify_file(path: str, config: dict) -> tuple[list[str], list[str]]:
    """Returns (risk_tags, candidate_repos) for a file path."""
    tags = set()
    candidate_repos = set()

    # Critical path check
    lower = path.lower()
    for cp in config.get("critical_paths", []):
        if cp.lower() in lower:
            tags.add("security-sensitive")
            break

    # Path risk rules
    for rule in config.get("path_risk_rules", []):
        if match_pattern(path, rule["pattern"]):
            tags.update(rule.get("tags", []))

    # Cross-repo rules
    for rule in config.get("cross_repo_rules", []):
        if match_pattern(path, rule["pattern"]):
            candidate_repos.update(rule.get("candidate_repos", []))

    return sorted(tags), sorted(candidate_repos)


def determine_size(total_lines: int, is_critical: bool, config: dict) -> str:
    if is_critical:
        return "deep"
    thresholds = config.get("size_thresholds", {"quick": 50, "standard": 300})
    if total_lines < thresholds.get("quick", 50):
        return "quick"
    if total_lines < thresholds.get("standard", 300):
        return "standard"
    return "deep"


def select_reviewers(
    all_tags: set,
    changed_repos: list,
    must_check_non_empty: bool,
    config: dict,
) -> tuple[list[str], dict]:
    reviewers = ["codex-baseline", "opus-baseline"]
    why = {}

    for rule in config.get("reviewer_rules", []):
        reviewer = rule["reviewer"]
        conditions = rule.get("conditions", {})

        match = True
        reasons = []

        if "changed_repos_include" in conditions:
            overlap = set(changed_repos) & set(conditions["changed_repos_include"])
            if not overlap:
                match = False
            else:
                reasons.append(f"changed_repos includes {sorted(overlap)}")

        if "any_tag" in conditions:
            tag_overlap = all_tags & set(conditions["any_tag"])
            if not tag_overlap:
                match = False
            else:
                reasons.append(f"risk_tags include {sorted(tag_overlap)}")

        if "must_check_interfaces_non_empty" in conditions:
            if not must_check_non_empty:
                match = False
            else:
                reasons.append("must_check_interfaces is non-empty")

        if match and reviewer not in reviewers:
            reviewers.append(reviewer)
            why[reviewer] = ", ".join(reasons)

    return reviewers, why


def build_must_check_interfaces(
    changed_files: list[dict],
    all_candidate_repos: dict,
    config: dict,
) -> list[dict]:
    """Build must_check_interfaces from changed proto/schema/env files."""
    interfaces = []
    seen = set()

    for f in changed_files:
        path = f["path"]
        repo = f["repo"]
        candidates = all_candidate_repos.get(f"{repo}:{path}", [])
        if not candidates:
            continue

        # Proto files → RPC interface
        if path.endswith(".proto"):
            key = f"{repo}:{path}"
            if key not in seen:
                seen.add(key)
                interfaces.append({
                    "type": "proto",
                    "name": os.path.basename(path),
                    "source_repo": repo,
                    "source_path": path,
                    "candidate_repos": candidates,
                })

        # Env var files
        elif any(match_pattern(path, p) for p in ["*.env*", "**/secret*"]):
            key = f"{repo}:{path}"
            if key not in seen:
                seen.add(key)
                interfaces.append({
                    "type": "env_var",
                    "name": os.path.basename(path),
                    "source_repo": repo,
                    "source_path": path,
                    "candidate_repos": candidates,
                })

        # Schema files
        elif any(match_pattern(path, p) for p in ["schema/**", "**/migrations/**"]):
            key = f"{repo}:{path}"
            if key not in seen:
                seen.add(key)
                interfaces.append({
                    "type": "schema",
                    "name": os.path.basename(path),
                    "source_repo": repo,
                    "source_path": path,
                    "candidate_repos": candidates,
                })

    return interfaces


def main():
    parser = argparse.ArgumentParser(description="review-triage: produce triage JSON")
    parser.add_argument("--local-diff", action="store_true", help="local-diff mode (no PR)")
    parser.add_argument("--pr-ref", default=None, help="PR reference e.g. github.com/org/repo#123")
    parser.add_argument("--base-sha", required=True)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument(
        "--repo",
        action="append",
        dest="repos",
        metavar="NAME:PATH",
        help="Repo name:local path. Can be repeated.",
        default=[],
    )
    parser.add_argument("--diff-stat", help="Path to file containing git diff --stat output")
    parser.add_argument(
        "--changed-files",
        help="Path to JSON file: [{repo, path, status, additions, deletions}]",
    )
    parser.add_argument("--pr-title", default="")
    parser.add_argument("--pr-labels", default="", help="Comma-separated labels")
    parser.add_argument("--pr-author", default="")
    parser.add_argument("--output", "-o", default="-", help="Output file path (- for stdout)")

    args = parser.parse_args()

    config = load_config()

    # Parse repos
    repo_roots = {}
    for r in args.repos:
        if ":" not in r:
            print(f"ERROR: --repo must be NAME:PATH, got: {r}", file=sys.stderr)
            sys.exit(1)
        name, path = r.split(":", 1)
        repo_roots[name] = path

    # Load changed files
    changed_files = []
    if args.changed_files:
        with open(args.changed_files) as f:
            changed_files = json.load(f)
    elif not sys.stdin.isatty():
        changed_files = json.load(sys.stdin)

    if not changed_files:
        print("ERROR: No changed files provided. Use --changed-files or stdin.", file=sys.stderr)
        sys.exit(1)

    # Classify each file
    all_tags: set[str] = set()
    all_candidate_repos: dict[str, list[str]] = {}
    changed_repos: set[str] = set()
    is_critical = False
    total_lines = 0

    for f in changed_files:
        path = f["path"]
        repo = f.get("repo", list(repo_roots.keys())[0] if repo_roots else "unknown")
        f["repo"] = repo
        changed_repos.add(repo)

        tags, candidates = classify_file(path, config)
        all_tags.update(tags)
        if candidates:
            all_candidate_repos[f"{repo}:{path}"] = candidates

        # Check if critical
        lower = path.lower()
        for cp in config.get("critical_paths", []):
            if cp.lower() in lower:
                is_critical = True
                break

        additions = f.get("additions", 0)
        deletions = f.get("deletions", 0)
        total_lines += additions + deletions

    # Also apply breaking-change tag to label-driven detection
    if args.pr_labels:
        labels = [l.strip().lower() for l in args.pr_labels.split(",")]
        if any("breaking" in l for l in labels):
            all_tags.add("breaking-change")

    # Build must_check_interfaces
    must_check = build_must_check_interfaces(changed_files, all_candidate_repos, config)

    # Select reviewers
    reviewers, why_selected = select_reviewers(
        all_tags,
        list(changed_repos),
        bool(must_check),
        config,
    )

    # Determine size
    size = determine_size(total_lines, is_critical, config)

    # Build triage output
    input_mode = "local-diff" if args.local_diff else "pr"
    triage = {
        "schema_version": 1,
        "input_mode": input_mode,
        "pr_ref": None if input_mode == "local-diff" else args.pr_ref,
        "base_sha": args.base_sha,
        "head_sha": args.head_sha,
        "repo_roots": repo_roots,
        "size": size,
        "risk_tags": sorted(all_tags),
        "changed_files": changed_files,
        "changed_symbols": [],
        "changed_protos": [
            {"repo": f["repo"], "path": f["path"]}
            for f in changed_files
            if f["path"].endswith(".proto")
        ],
        "changed_env_vars": [],
        "changed_schemas": [],
        "selected_reviewers": reviewers,
        "why_selected": why_selected,
        "global_token_budget": config.get("token_budget", {}).get("global", 200000),
        "per_reviewer_budget": config.get("token_budget", {}).get("per_reviewer", 50000),
        "must_check_interfaces": must_check,
    }

    if args.pr_title or args.pr_labels or args.pr_author:
        triage["pr_metadata"] = {
            "title": args.pr_title,
            "labels": [l.strip() for l in args.pr_labels.split(",") if l.strip()],
            "author": args.pr_author,
        }

    output = json.dumps(triage, ensure_ascii=False, indent=2)

    if args.output == "-":
        print(output)
    else:
        Path(args.output).write_text(output)
        print(f"Triage written to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
